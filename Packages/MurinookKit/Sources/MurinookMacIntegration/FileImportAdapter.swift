import AppKit
import OSLog
import Foundation
import UniformTypeIdentifiers
import MurinookDomain

public struct ImportedFile: Sendable, Hashable {
    public let url: URL
    public let displayName: String
    public let typeIdentifier: String?
    public let bookmark: Data?
    public let isOwnedCopy: Bool
    public let byteCount: Int?

    public init(url: URL, displayName: String, typeIdentifier: String?, bookmark: Data?, isOwnedCopy: Bool, byteCount: Int? = nil) {
        self.url = url
        self.displayName = displayName
        self.typeIdentifier = typeIdentifier
        self.bookmark = bookmark
        self.isOwnedCopy = isOwnedCopy
        self.byteCount = byteCount
    }
}

public enum FileImportError: Error, LocalizedError, Sendable {
    case bookmarkCreationFailed(String)
    case promiseUnavailable
    case promiseFailed(String)
    case storageFailed(String)
    case unreadableFileURL

    public var errorDescription: String? {
        switch self {
        case .bookmarkCreationFailed(let detail): "Could not create access to the dropped file: \(detail)"
        case .promiseUnavailable: "The source did not provide a readable promised file."
        case .promiseFailed(let detail): "The source could not provide the promised file: \(detail)"
        case .storageFailed(let detail): "The imported file could not be stored: \(detail)"
        case .unreadableFileURL: "The source did not provide a readable file URL."
        }
    }
}

public struct BookmarkResolution: Sendable, Hashable {
    public let url: URL
    public let isStale: Bool
    public let refreshedBookmark: Data?
}

@MainActor
public final class BookmarkAdapter {
    private let logger = Logger(subsystem: "wonsky.Murinook", category: "BookmarkAccess")
    private var activeAccessCounts: [URL: Int] = [:]
    private let diagnostics: DragDiagnostics?

    public init(diagnostics: DragDiagnostics? = nil) { self.diagnostics = diagnostics }

    public func createBookmark(for url: URL) throws -> Data {
        try createBookmark(for: url as NSURL)
    }

    public func createBookmark(for url: NSURL) throws -> Data {
        let acquired = url.startAccessingSecurityScopedResource()
        var fields: [String: String] = [:]
        if let diagnostics {
            fields = diagnostics.fileFields(url).merging(["scopeStarted": String(acquired),
                "isReadable": String(FileManager.default.isReadableFile(atPath: (url as URL).path)),
                "isReachable": String((try? (url as URL).checkResourceIsReachable()) ?? false)]) { _, new in new }
        }
        diagnostics?.event("bookmark.create.begin", fields: fields)
        defer {
            if acquired {
                url.stopAccessingSecurityScopedResource()
                diagnostics?.event("bookmark.create.scope_stopped", fields: fields)
            }
        }
        // Shelf transfers read/copy the original; a Finder drop need not grant write access.
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            diagnostics?.event("bookmark.create.success", fields: fields.merging(["bookmarkLength": String(bookmark.count)]) { _, new in new })
            return bookmark
        }
        catch {
            diagnostics?.event("bookmark.create.failure", fields: fields.merging(diagnostics?.errorFields(error) ?? [:]) { _, new in new })
            let failure = error as NSError
            let readable = url.checkResourceIsReachableAndReturnError(nil)
            let underlying = (failure.userInfo[NSUnderlyingErrorKey] as? NSError)
            logger.error("Bookmark creation failed; scope acquired: \(acquired); reachable: \(readable); domain: \(failure.domain, privacy: .public); code: \(failure.code); underlying domain: \(underlying?.domain ?? "none", privacy: .public); underlying code: \(underlying?.code ?? 0)")
            throw FileImportError.bookmarkCreationFailed(error.localizedDescription)
        }
    }

    public func resolve(_ bookmark: Data) throws -> URL {
        try resolveBookmark(bookmark).url
    }

    public func resolveBookmark(_ bookmark: Data) throws -> BookmarkResolution {
        diagnostics?.event("bookmark.resolve.begin", fields: ["bookmarkLength": String(bookmark.count)])
        var stale = false
        let url: URL
        do { url = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale) }
        catch {
            diagnostics?.event("bookmark.resolve.failure", fields: diagnostics?.errorFields(error) ?? [:])
            throw error
        }
        diagnostics?.event("bookmark.resolve.success", fields: (diagnostics?.fileFields(url as NSURL) ?? [:]).merging(["stale": String(stale)]) { _, new in new })
        return BookmarkResolution(url: url, isStale: stale, refreshedBookmark: stale ? try createBookmark(for: url) : nil)
    }

    @discardableResult
    public func startAccessing(_ url: URL) -> Bool {
        if let count = activeAccessCounts[url] {
            activeAccessCounts[url] = count + 1
            diagnostics?.event("bookmark.scope.retain", fields: (diagnostics?.fileFields(url as NSURL) ?? [:]).merging(["count": String(count + 1)]) { _, new in new })
            return true
        }
        let started = url.startAccessingSecurityScopedResource()
        if started { activeAccessCounts[url] = 1 }
        diagnostics?.event("bookmark.scope.start", fields: (diagnostics?.fileFields(url as NSURL) ?? [:]).merging(["started": String(started), "count": started ? "1" : "0"]) { _, new in new })
        return started
    }

    public func stopAccessing(_ url: URL) {
        guard let count = activeAccessCounts[url] else { return }
        if count > 1 {
            activeAccessCounts[url] = count - 1
            diagnostics?.event("bookmark.scope.release", fields: (diagnostics?.fileFields(url as NSURL) ?? [:]).merging(["count": String(count - 1)]) { _, new in new })
        } else {
            activeAccessCounts.removeValue(forKey: url)
            url.stopAccessingSecurityScopedResource()
            diagnostics?.event("bookmark.scope.stop", fields: (diagnostics?.fileFields(url as NSURL) ?? [:]).merging(["count": "0"]) { _, new in new })
        }
    }

    public func withAccess<T>(to url: URL, perform body: () throws -> T) rethrows -> T {
        let acquired = startAccessing(url)
        defer { if acquired { stopAccessing(url) } }
        return try body()
    }

    public func releaseAllAccess() {
        for (url, count) in activeAccessCounts {
            url.stopAccessingSecurityScopedResource()
            diagnostics?.event("bookmark.scope.release-all", fields: (diagnostics?.fileFields(url as NSURL) ?? [:]).merging(["count": String(count)]) { _, new in new })
        }
        activeAccessCounts.removeAll()
    }
}

@MainActor
public final class FileImportAdapter {
    private let bookmarks: BookmarkAdapter
    private let ownedFilesDirectory: URL
    private let fileManager: FileManager
    private let ownedStorage: OwnedFileStorage
    private let diagnostics: DragDiagnostics?

    public init(bookmarks: BookmarkAdapter, ownedFilesDirectory: URL, fileManager: FileManager = .default, diagnostics: DragDiagnostics? = nil) throws {
        self.bookmarks = bookmarks
        self.ownedFilesDirectory = ownedFilesDirectory
        self.fileManager = fileManager
        self.ownedStorage = OwnedFileStorage(directory: ownedFilesDirectory)
        self.diagnostics = diagnostics
        try fileManager.createDirectory(at: ownedFilesDirectory, withIntermediateDirectories: true)
    }

    /// Retains the external original and returns a bookmark for later scoped access.
    public func referenceExternalFile(at url: URL) throws -> ImportedFile {
        let bookmark = try bookmarks.createBookmark(for: url)
        return ImportedFile(url: url, displayName: url.lastPathComponent, typeIdentifier: Self.typeIdentifier(for: url), bookmark: bookmark, isOwnedCopy: Self.isOwnedFile(url, inside: ownedFilesDirectory), byteCount: Self.fileByteCount(at: url))
    }

    /// Read real file URLs while AppKit's drop grant is active; no document-type filtering.
    public func captureExternalFiles(from pasteboard: NSPasteboard) throws -> [ImportedFile] {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [NSURL] ?? []
        let dragID = diagnostics?.beginDrag(changeCount: pasteboard.changeCount, fields: ["capture": "external-file-urls", "count": String(urls.count)])
        diagnostics?.event("file-import.capture.urls", fields: ["changeCount": String(pasteboard.changeCount), "count": String(urls.count)], dragID: dragID)
        return try urls.enumerated().map { index, source in
            var fields = diagnostics?.fileFields(source) ?? [:]
            fields["index"] = String(index)
            diagnostics?.event("file-import.capture.file.begin", fields: fields, dragID: dragID)
            do {
                let bookmark = try bookmarks.createBookmark(for: source)
                let url = source as URL
                let result = ImportedFile(url: url, displayName: url.lastPathComponent, typeIdentifier: Self.typeIdentifier(for: url), bookmark: bookmark,
                                          isOwnedCopy: Self.isOwnedFile(url, inside: ownedFilesDirectory), byteCount: Self.fileByteCount(at: url))
                diagnostics?.event("file-import.capture.file.success", fields: fields.merging(["bookmarkLength": String(bookmark.count), "isOwnedCopy": String(result.isOwnedCopy), "byteCount": result.byteCount.map { String($0) } ?? "unknown"]) { _, new in new }, dragID: dragID)
                return result
            } catch {
                diagnostics?.event("file-import.capture.file.failure", fields: fields.merging(diagnostics?.errorFields(error) ?? [:]) { _, new in new }, dragID: dragID)
                throw error
            }
        }
    }

    public func importExternalFiles(_ files: [ImportedFile]) async throws -> [ClipContent] {
        files.map { file in
            ClipContent(files: [FileReference(url: file.url, bookmark: file.bookmark,
                isOwnedCopy: file.isOwnedCopy, byteCount: file.byteCount)])
        }
    }

    /// Imports real payloads from an outbound or foreign NSItemProvider without substituting placeholder data.
    public func importProviders(_ providers: [NSItemProvider]) async throws -> [ClipContent] {
        var imported: [ClipContent] = []
        let promiseTypes = Set(NSFilePromiseReceiver.readableDraggedTypes)
        var totalRepresentationBytes = 0
        let maximumRepresentationBytes = 32 * 1_024 * 1_024
        for provider in providers {
            let privacyMarkers: Set<String> = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
            guard provider.registeredTypeIdentifiers.allSatisfy({ !privacyMarkers.contains($0) }) else { continue }
            var files: [FileReference] = []
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                guard let url = await loadFileURL(from: provider), url.isFileURL else {
                    throw FileImportError.unreadableFileURL
                }
                let file = try referenceExternalFile(at: url)
                files.append(FileReference(url: file.url, bookmark: file.bookmark,
                    isOwnedCopy: file.isOwnedCopy, byteCount: file.byteCount))
            } else if let promiseType = provider.registeredTypeIdentifiers.first(where: promiseTypes.contains),
                      let file = try? await receiveFileRepresentation(from: provider, typeIdentifier: promiseType) {
                files.append(file)
            }

            // A file provider may advertise only its actual type (DOCX, PDF, archives, arbitrary data).
            // Request its native file representation rather than treating it as a clipboard byte blob.
            if files.isEmpty {
                for identifier in provider.registeredTypeIdentifiers {
                    guard Self.isFileRepresentationCandidate(identifier),
                          let file = try? await receiveFileRepresentation(from: provider, typeIdentifier: identifier) else { continue }
                    files.append(file)
                    break
                }
            }

            if !files.isEmpty {
                imported.append(ClipContent(files: files))
                continue
            }

            var representations: [ClipRepresentation] = []
            var filePayloadTypes = promiseTypes
            filePayloadTypes.insert("public.file-url")
            for identifier in provider.registeredTypeIdentifiers where !filePayloadTypes.contains(identifier) {
                guard let data = try? await loadDataRepresentation(from: provider, typeIdentifier: identifier),
                      data.count <= maximumRepresentationBytes,
                      totalRepresentationBytes + data.count <= maximumRepresentationBytes else { continue }
                totalRepresentationBytes += data.count
                representations.append(ClipRepresentation(typeIdentifier: identifier, data: data))
            }
            if !representations.isEmpty {
                imported.append(ClipContent(representations: representations))
            }
        }
        return imported
    }

    /// Copies a dropped file into app-owned storage; the copy needs no external bookmark.
    public func makeOwnedCopy(of url: URL) throws -> ImportedFile {
        do {
            let destination = try bookmarks.withAccess(to: url) { try OwnedFileStorage.copy(url, into: ownedFilesDirectory) }
            return ImportedFile(url: destination, displayName: url.lastPathComponent, typeIdentifier: Self.typeIdentifier(for: destination), bookmark: nil, isOwnedCopy: true, byteCount: Self.fileByteCount(at: destination))
        } catch { throw FileImportError.storageFailed(error.localizedDescription) }
    }

    /// Materializes an ephemeral transfer. Ordinary shelf files use referenceExternalFile instead.
    public func importExternalFile(at url: URL) async throws -> ImportedFile {
        let acquired = bookmarks.startAccessing(url)
        defer { if acquired { bookmarks.stopAccessing(url) } }
        let destination = try await ownedStorage.copy(url)
        return ImportedFile(url: destination, displayName: url.lastPathComponent,
            typeIdentifier: Self.typeIdentifier(for: destination), bookmark: nil,
            isOwnedCopy: true, byteCount: Self.fileByteCount(at: destination))
    }

    /// File promises must be read during the destination callback. Their data is materialized into app-owned storage.
    public func receivePromises(from pasteboard: NSPasteboard) async throws -> [ImportedFile] {
        try await receivePromises(capturePromiseReceivers(from: pasteboard))
    }

    /// Captures receiver objects synchronously while AppKit's drag destination callback is active.
    public func capturePromiseReceivers(from pasteboard: NSPasteboard) throws -> [NSFilePromiseReceiver] {
        let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver] ?? []
        let dragID = diagnostics?.beginDrag(changeCount: pasteboard.changeCount, fields: ["capture": "promise-receivers", "count": String(receivers.count)])
        diagnostics?.event("file-import.capture.promises", fields: ["changeCount": String(pasteboard.changeCount), "count": String(receivers.count)], dragID: dragID)
        guard !receivers.isEmpty else {
            throw FileImportError.promiseUnavailable
        }
        return receivers
    }

    /// Receives already-captured promises; call `capturePromiseReceivers` from the drop callback first.
    public func receivePromises(_ receivers: [NSFilePromiseReceiver]) async throws -> [ImportedFile] {
        let batch = try beginReceivingPromises(receivers)
        return try await batch.value()
    }

    /// Starts every file promise synchronously. Call from `prepareForDragOperation`,
    /// `performDragOperation`, or `concludeDragOperation` while AppKit's drop callback
    /// is active, then await the returned batch after that callback returns.
    public func beginReceivingPromises(_ receivers: [NSFilePromiseReceiver]) throws -> PromiseReceiveBatch {
        guard !receivers.isEmpty else { throw FileImportError.promiseUnavailable }
        let stagingDirectory = ownedFilesDirectory.appendingPathComponent(".promise-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let group = PromiseReceiveGroup(stagingDirectory: stagingDirectory,
            destinationDirectory: ownedFilesDirectory, fileManager: fileManager)
        var expectedFiles = 0
        for receiver in receivers {
            diagnostics?.event("file-import.promise.receive.begin", fields: ["filenameCount": String(receiver.fileNames.count), "filenames": receiver.fileNames.joined(separator: ",")])
            receiver.receivePromisedFiles(atDestination: stagingDirectory, options: [:], operationQueue: .main) { fileURL, error in
                Task { @MainActor in
                    if let error { self.diagnostics?.event("file-import.promise.receive.failure", fields: self.diagnostics?.errorFields(error) ?? [:]) }
                    else { self.diagnostics?.event("file-import.promise.receive.file", fields: self.diagnostics?.fileFields(fileURL as NSURL) ?? [:]) }
                    group.record(url: fileURL, error: error)
                }
            }
            expectedFiles += max(receiver.fileNames.count, 1)
        }
        group.setExpectedCount(expectedFiles)
        return PromiseReceiveBatch(group: group)
    }

    private static func typeIdentifier(for url: URL) -> String? {
        (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.identifier
    }

    private static func fileByteCount(at url: URL) -> Int? {
        try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        if let data = try? await loadDataRepresentation(from: provider, typeIdentifier: UTType.fileURL.identifier),
           let value = String(data: data, encoding: .utf8),
           let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)), url.isFileURL {
            return url
        }
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: NSURL.self) { object, _ in
                continuation.resume(returning: object as? URL)
            }
        }
    }

    private func loadDataRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: data) }
            }
        }
    }

    private func receiveFileRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> FileReference {
        let destinationDirectory = ownedFilesDirectory
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeIdentifier) { url, isInPlace, error in
                guard let url else {
                    continuation.resume(throwing: error ?? FileImportError.promiseUnavailable)
                    return
                }
                do {
                    if isInPlace {
                        // Capture access before the provider callback's grant expires.
                        let bookmark = try url.bookmarkData(options: [],
                            includingResourceValuesForKeys: nil, relativeTo: nil)
                        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                        continuation.resume(returning: FileReference(url: url, bookmark: bookmark, isOwnedCopy: Self.isOwnedFile(url, inside: destinationDirectory), byteCount: size))
                    } else {
                        // Ephemeral provider URLs cease to exist after this callback.
                        let destination = try OwnedFileStorage.copy(url, into: destinationDirectory)
                        let size = (try? destination.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                        continuation.resume(returning: FileReference(url: destination, isOwnedCopy: true, byteCount: size))
                    }
                } catch {
                    continuation.resume(throwing: FileImportError.storageFailed(error.localizedDescription))
                }
            }
        }
    }

    nonisolated private static func isOwnedFile(_ url: URL, inside root: URL) -> Bool {
        let directory = root.resolvingSymlinksInPath().standardizedFileURL.path
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return path.hasPrefix(directory + "/")
    }

    private static func isFileRepresentationCandidate(_ identifier: String) -> Bool {
        if identifier == ContentItemProviderFactory.ownedFileTransferType { return false }
        guard let type = UTType(identifier) else { return true }
        return !type.conforms(to: .text) && !type.conforms(to: .image)
            && !type.conforms(to: .url) && identifier != "public.color"
    }
}

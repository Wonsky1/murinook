import AppKit
import Foundation
import MurinookDomain
import MurinookUseCases
import UniformTypeIdentifiers

/// Builds providers backed by the exact captured representations and/or original file URLs.
public struct ContentItemProviderFactory: Sendable {
    static let ownedFileTransferType = "com.murinook.content-provider-owned-file"
    public init() {}

    /// Creates a lazy provider: repository payloads are loaded only when the receiving app requests a representation.
    @MainActor
    public func makeProvider(contentID: UUID, kind: ClipKind = .text, contents: any ContentRepository) -> NSItemProvider {
        let provider = NSItemProvider()
        let repository = ContentRepositoryHandle(contents)
        let transfers = ProviderFileAccess()
        let bookmarks = BookmarkAdapter()
        let identifiers = Self.advertisedTypeIdentifiers(for: kind)


        for identifier in identifiers {
            provider.registerDataRepresentation(forTypeIdentifier: identifier, visibility: .all) { completion in
                let progress = Progress(totalUnitCount: 1)
                Task { @MainActor in
                    do {
                        let content = try await repository.get(contentID)
                        if identifier == "public.file-url", let file = content.files.first {
                            let original = try transfers.resolvedOriginal(of: file, bookmarks: bookmarks)
                            completion(Data(original.absoluteString.utf8), nil)
                        } else if let representation = content.representations.first(where: { $0.typeIdentifier == identifier }) {
                            completion(representation.data, nil)
                        } else {
                            completion(nil, ContentProviderError.representationUnavailable(identifier))
                        }
                        progress.completedUnitCount = 1
                    } catch { completion(nil, error) }
                }
                return progress
            }
        }

        if kind == .file {
            for identifier in Self.fileRepresentationTypeIdentifiers {
                provider.registerFileRepresentation(forTypeIdentifier: identifier, fileOptions: .openInPlace, visibility: .all) { completion in
                    let progress = Progress(totalUnitCount: 1)
                    Task { @MainActor in
                        do {
                            let content = try await repository.get(contentID)
                            guard let file = content.files.first(where: { Self.fileType($0.url, matches: identifier) }) else {
                                completion(nil, false, ContentProviderError.representationUnavailable(identifier))
                                return
                            }
                            let original = try transfers.resolvedOriginal(of: file, bookmarks: BookmarkAdapter())
                            completion(original, true, nil)
                            progress.completedUnitCount = 1
                        } catch { completion(nil, false, error) }
                    }
                    return progress
                }
            }
        }
        return provider
    }

    @MainActor
    public func makeProvider(for content: ClipContent) -> NSItemProvider {
        makeProvider(for: content, bookmarks: BookmarkAdapter())
    }

    @MainActor
    private func makeProvider(for content: ClipContent, bookmarks: BookmarkAdapter) -> NSItemProvider {
        let provider = NSItemProvider()
        let transfers = ProviderFileAccess()
        let bookmarks = BookmarkAdapter()
        for representation in content.representations {
            if representation.typeIdentifier == "public.file-url", let file = content.files.first {
                Self.registerFileURLData(on: provider, file: file, transfers: transfers, bookmarks: bookmarks)
                continue
            }
            let data = representation.data
            provider.registerDataRepresentation(forTypeIdentifier: representation.typeIdentifier, visibility: .all) { completion in
                completion(data, nil)
                return nil
            }
        }
        if !content.representations.contains(where: { $0.typeIdentifier == "public.file-url" }), let file = content.files.first {
            Self.registerFileURLData(on: provider, file: file, transfers: transfers, bookmarks: bookmarks)
        }
        for file in content.files {
            let type = Self.typeIdentifier(for: file.url)
            provider.registerFileRepresentation(forTypeIdentifier: type, fileOptions: .openInPlace, visibility: .all) { completion in
                let progress = Progress(totalUnitCount: 1)
                Task { @MainActor in
                    do {
                        let original = try transfers.resolvedOriginal(of: file, bookmarks: bookmarks)
                        completion(original, true, nil)
                        progress.completedUnitCount = 1
                    } catch { completion(nil, false, error) }
                }
                return progress
            }
        }
        return provider
    }

    @MainActor
    public func makeProvider(for item: ClipboardItemSnapshot, fileURLs: [URL] = []) -> NSItemProvider {
        let provider = NSItemProvider()
        let transfers = ProviderFileAccess()
        let bookmarks = BookmarkAdapter()
        for representation in item.representations {
            if representation.typeIdentifier == "public.file-url", let file = item.files.first {
                Self.registerFileURLData(on: provider, file: file, transfers: transfers, bookmarks: bookmarks)
                continue
            }
            let data = representation.data
            provider.registerDataRepresentation(forTypeIdentifier: representation.typeIdentifier, visibility: .all) { completion in
                completion(data, nil)
                return nil
            }
        }
        let files = item.files + fileURLs.map { FileReference(url: $0) }
        if !item.representations.contains(where: { $0.typeIdentifier == "public.file-url" }), let file = files.first {
            Self.registerFileURLData(on: provider, file: file, transfers: transfers, bookmarks: bookmarks)
        }
        for file in files {
            let type = Self.typeIdentifier(for: file.url)
            provider.registerFileRepresentation(forTypeIdentifier: type, fileOptions: .openInPlace, visibility: .all) { completion in
                let progress = Progress(totalUnitCount: 1)
                Task { @MainActor in
                    do {
                        let original = try transfers.resolvedOriginal(of: file, bookmarks: bookmarks)
                        completion(original, true, nil)
                        progress.completedUnitCount = 1
                    } catch { completion(nil, false, error) }
                }
                return progress
            }
        }
        return provider
    }

    @MainActor
    public func makeProviders(for snapshot: ClipboardSnapshot) -> [NSItemProvider] {
        snapshot.items.map { makeProvider(for: $0) }
    }

    private static func typeIdentifier(for url: URL) -> String {
        (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.identifier) ?? "public.data"
    }

    private static let fileRepresentationTypeIdentifiers = [
        "public.data", "public.pdf", "public.image", "public.png", "public.jpeg", "public.tiff",
        "public.movie", "public.audio", "public.archive", "public.zip-archive", "public.folder"
    ]

    private static func advertisedTypeIdentifiers(for kind: ClipKind) -> [String] {
        switch kind {
        case .text: ["public.utf8-plain-text", "public.plain-text", "NSStringPboardType", "public.rtf", "public.html"]
        case .link: ["public.url", "public.utf8-plain-text", "public.plain-text", "public.html"]
        case .image: ["public.image", "public.png", "public.jpeg", "public.tiff", "public.heic", "com.compuserve.gif"]
        case .file: ["public.file-url", "public.data", "public.pdf", "public.image", "public.movie", "public.audio", "public.archive", "public.zip-archive"]
        case .code: ["public.utf8-plain-text", "public.plain-text", "NSStringPboardType", "public.rtf"]
        case .color: ["public.color", "public.utf8-plain-text", "public.plain-text"]
        }
    }

    private static func fileType(_ url: URL, matches requestedIdentifier: String) -> Bool {
        if requestedIdentifier == "public.data" { return true }
        guard let actual = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
              let requested = UTType(requestedIdentifier) else { return false }
        return actual == requested || actual.conforms(to: requested)
    }

    @MainActor
    private static func registerFileURLData(on provider: NSItemProvider, file: FileReference, transfers: ProviderFileAccess, bookmarks: BookmarkAdapter) {
        provider.registerDataRepresentation(forTypeIdentifier: "public.file-url", visibility: .all) { completion in
            let progress = Progress(totalUnitCount: 1)
            Task { @MainActor in
                do {
                    let original = try transfers.resolvedOriginal(of: file, bookmarks: bookmarks)
                    completion(Data(original.absoluteString.utf8), nil)
                    progress.completedUnitCount = 1
                } catch { completion(nil, error) }
            }
            return progress
        }
    }
}

private enum ContentProviderError: Error {
    case representationUnavailable(String)
}

private final class ContentRepositoryHandle: @unchecked Sendable {
    private let repository: any ContentRepository
    init(_ repository: any ContentRepository) { self.repository = repository }
    @MainActor func get(_ id: UUID) async throws -> ClipContent { try await repository.get(id) }
}

@MainActor
private final class ProviderFileAccess {
    private var accessedURLs: [URL] = []

    func resolvedOriginal(of reference: FileReference, bookmarks: BookmarkAdapter) throws -> URL {
        let source = try reference.bookmark.map(bookmarks.resolve) ?? reference.url
        if !accessedURLs.contains(source), source.startAccessingSecurityScopedResource() {
            accessedURLs.append(source)
        }
        return source
    }

    deinit {
        accessedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
    }
}

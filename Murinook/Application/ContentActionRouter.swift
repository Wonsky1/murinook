import MurinookStorage
import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers
import MurinookDomain
import MurinookUseCases
import MurinookMacIntegration

@Observable final class ContentActionRouter {
    private(set) var isPasting = false
    private let services: ApplicationServices
    private let errors: ErrorPresenter
    private let quickLook = QuickLookAdapter()
    private let exporter = ExportAdapter()
    private var previewHasLease = false
    private var previewTemporaryFiles: [URL] = []
    private var previewAccess: [URL] = []
    var beforePaste: (() -> Void)?

    init(services: ApplicationServices, errors: ErrorPresenter) {
        self.services = services
        self.errors = errors
        quickLook.onClose = { [weak self] in self?.releasePreviewAccess() }
        let stale = FileManager.default.temporaryDirectory.appending(path: "MurinookPreviews", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: stale)
    }

    func copy(_ contentID: UUID, plain: Bool = false) {
        Task {
            await services.contentAccess.withAccess {
                do {
                    let content = try resolveContentFiles(await services.storage.contents.get(contentID))
                    if plain, let text = content.plainText { _ = try services.writer.writePlainText(text) }
                    else { _ = try services.writer.write(content) }
                } catch { errors.show("Could not copy item", detail: error.localizedDescription) }
            }
        }
    }

    func paste(_ contentID: UUID, plain: Bool = false, queueID: UUID? = nil) {
        guard !isPasting else { return }
        isPasting = true
        Task {
            await services.contentAccess.withAccess {
                defer { isPasting = false }
                do {
                    let content = try resolveContentFiles(await services.storage.contents.get(contentID))
                    beforePaste?()
                    let result = await services.dispatcher.paste(content, plainTextOnly: plain)
                    switch result.status {
                    case .dispatched:
                        if let queueID { services.queue.remove(queueID) }
                    case .accessibilityPermissionRequired:
                        errors.show("Allow Accessibility to paste into other apps")
                        services.permission.requestPostEventAccess()
                    case .clipboardWriteFailed, .commandDispatchFailed, .destinationUnavailable:
                        errors.show("Could not paste item", detail: result.detail)
                    }
                } catch { errors.show("Could not load item", detail: error.localizedDescription) }
            }
        }
    }

    func addToShelf(_ clip: Clip) {
        Task {
            await services.contentAccess.withAccess {
                do {
                    _ = try await services.storage.contents.get(clip.contentID)
                    await services.shelf.add(contentID: clip.contentID, title: clip.title,
                        kind: clip.kind, iconData: clip.iconData)
                } catch { errors.show("Could not load item", detail: error.localizedDescription) }
            }
        }
    }

    func addToQueue(_ clip: Clip) {
        Task {
            await services.contentAccess.withAccess {
                do {
                    _ = try await services.storage.contents.get(clip.contentID)
                    services.queue.add(contentID: clip.contentID, title: clip.title, kind: clip.kind)
                } catch { errors.show("Could not load item", detail: error.localizedDescription) }
            }
        }
    }

    func preview(_ contentID: UUID) {
        Task {
            await services.contentAccess.withAccess {
                do {
                    let content = try await services.storage.contents.get(contentID)
                    releasePreviewAccess()
                    guard services.contentAccess.tryBeginAccess() else { return }
                    previewHasLease = true
                    var urls = try resolvedFiles(content)
                    for url in urls where services.bookmarks.startAccessing(url) { previewAccess.append(url) }
                    if urls.isEmpty {
                        let directory = FileManager.default.temporaryDirectory.appending(path: "MurinookPreviews", directoryHint: .isDirectory)
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        let image = content.representations.first { UTType($0.typeIdentifier)?.conforms(to: .image) == true }
                        let representation = image ?? content.representations.first { $0.typeIdentifier == UTType.rtf.identifier }
                        if let representation {
                            let ext = UTType(representation.typeIdentifier)?.preferredFilenameExtension ?? "data"
                            let url = directory.appending(path: contentID.uuidString + "." + ext)
                            try representation.data.write(to: url, options: .atomic)
                            previewTemporaryFiles.append(url)
                            urls = [url]
                        } else if let text = content.plainText {
                            let url = directory.appending(path: contentID.uuidString + ".txt")
                            try Data(text.utf8).write(to: url, options: .atomic)
                            previewTemporaryFiles.append(url)
                            urls = [url]
                        }
                    }
                    guard !urls.isEmpty else { releasePreviewAccess(); errors.show("No preview is available for this item"); return }
                    if !quickLook.preview(urls) { releasePreviewAccess() }
                } catch { releasePreviewAccess(); errors.show("Could not preview item", detail: error.localizedDescription) }
            }
        }
    }

    func reveal(_ contentID: UUID) {
        Task {
            await services.contentAccess.withAccess {
                do {
                    let content = try await services.storage.contents.get(contentID)
                    let urls = try resolvedFiles(content)
                    guard !urls.isEmpty else { return }
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                } catch { errors.show("Could not find file", detail: error.localizedDescription) }
            }
        }
    }

    func export(_ ids: Set<UUID>) {
        Task {
            await services.contentAccess.withAccess {
                do {
                    let selected = services.history.clips.filter { ids.contains($0.id) }
                    if selected.count == 1, let clip = selected.first {
                        let content = try await services.storage.contents.get(clip.contentID)
                        if let url = try resolvedFiles(content).first {
                            let accessing = services.bookmarks.startAccessing(url)
                            defer { if accessing { services.bookmarks.stopAccessing(url) } }
                            _ = try await exporter.export(fileAt: url)
                        } else if let representation = content.representations.first(where: {
                            UTType($0.typeIdentifier)?.conforms(to: .image) == true
                        }) {
                            _ = try await exporter.export(data: representation.data, suggestedName: clip.title,
                                contentType: UTType(representation.typeIdentifier))
                        } else {
                            _ = try await exporter.export(data: Data((content.plainText ?? clip.preview).utf8),
                                suggestedName: clip.title + ".txt", contentType: .plainText)
                        }
                    } else if !selected.isEmpty {
                        let archive = try BulkExportArchive()
                        defer { Task { await archive.dispose() } }
                        for clip in selected {
                            let content = try await services.storage.contents.get(clip.contentID)
                            try await archive.append(clip: clip, content: content)
                        }
                        let url = try await archive.finish()
                        _ = try await exporter.export(fileAt: url, suggestedName: "Murinook.json")
                    }
                } catch { errors.show("Could not export items", detail: error.localizedDescription) }
            }
        }
    }

    private func resolveContentFiles(_ content: ClipContent) throws -> ClipContent {
        let files = try content.files.map { file in
            var resolved = file
            if let bookmark = file.bookmark { resolved.url = try services.bookmarks.resolve(bookmark) }
            return resolved
        }
        return ClipContent(representations: content.representations, files: files)
    }

    private func resolvedFiles(_ content: ClipContent) throws -> [URL] {
        try content.files.map { file in
            if let bookmark = file.bookmark { return try services.bookmarks.resolve(bookmark) }
            return file.url
        }
    }

    func stop() { quickLook.close(); releasePreviewAccess() }

    private func releasePreviewAccess() {
        for url in previewAccess { services.bookmarks.stopAccessing(url) }
        previewAccess.removeAll()
        previewTemporaryFiles.forEach { try? FileManager.default.removeItem(at: $0) }
        previewTemporaryFiles.removeAll()
        if previewHasLease { previewHasLease = false; services.contentAccess.endAccess() }
    }
}

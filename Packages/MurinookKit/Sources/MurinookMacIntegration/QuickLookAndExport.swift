import AppKit
import Foundation
import QuickLookUI
import UniformTypeIdentifiers

@MainActor
public final class QuickLookAdapter: NSObject, @preconcurrency QLPreviewPanelDataSource {
    private var previewURLs: [URL] = []
    public var onClose: (() -> Void)?
    private var observedPanel: QLPreviewPanel?

    public override init() { super.init() }

    @discardableResult public func preview(_ url: URL) -> Bool { preview([url], selecting: 0) }

    @discardableResult public func preview(_ urls: [URL], selecting index: Int = 0) -> Bool {
        previewURLs = urls
        guard let panel = QLPreviewPanel.shared() else { previewURLs = []; return false }
        if observedPanel !== panel {
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: observedPanel)
            NotificationCenter.default.addObserver(self, selector: #selector(panelClosed), name: NSWindow.willCloseNotification, object: panel)
            observedPanel = panel
        }
        panel.dataSource = self
        panel.currentPreviewItemIndex = min(max(index, 0), max(0, urls.count - 1))
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
        return true
    }

    public func close() {
        observedPanel?.close()
        panelClosed()
    }

    @objc private func panelClosed() {
        previewURLs.removeAll()
        onClose?()
    }

    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { previewURLs.count }

    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard previewURLs.indices.contains(index) else { return nil }
        return previewURLs[index] as NSURL
    }
}

@MainActor
public final class ExportAdapter {
    public init() {}

    /// Presents a native save panel and atomically writes the supplied representation.
    public func export(data: Data, suggestedName: String, contentType: UTType? = nil) async throws -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        if let contentType { panel.allowedContentTypes = [contentType] }
        guard await panel.begin() == .OK, let url = panel.url else { return nil }
        try await Task.detached(priority: .utility) { try data.write(to: url, options: .atomic) }.value
        return url
    }

    /// Exports a file by copying it; the source, especially an external original, remains owned by its source.
    public func export(fileAt source: URL, suggestedName: String? = nil) async throws -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName ?? source.lastPathComponent
        if let type = try? source.resourceValues(forKeys: [.contentTypeKey]).contentType { panel.allowedContentTypes = [type] }
        guard await panel.begin() == .OK, let destination = panel.url else { return nil }
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        try await Task.detached(priority: .utility) { try Self.copyFile(source: source, to: destination) }.value
        return destination
    }

    /// Copies through a sibling temporary item so a failed export leaves an existing destination intact.
    /// Refuses source aliases before replacing anything, which prevents a save-panel selection from deleting its source.
    nonisolated static func copyFile(source: URL, to destination: URL, fileManager: FileManager = .default) throws {
        let canonicalSource = source.standardizedFileURL.resolvingSymlinksInPath()
        let canonicalDestination = destination.standardizedFileURL.resolvingSymlinksInPath()
        guard canonicalSource != canonicalDestination,
              !canonicalSource.path.hasPrefix(canonicalDestination.path + "/"),
              !canonicalDestination.path.hasPrefix(canonicalSource.path + "/") else { throw ExportError.sourceAndDestinationAreSame }

        let directory = destination.deletingLastPathComponent()
        let temporary = directory.appendingPathComponent(".murinook-export-\(UUID().uuidString)-\(destination.lastPathComponent)")
        defer { try? fileManager.removeItem(at: temporary) }
        try fileManager.copyItem(at: source, to: temporary)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary, backupItemName: nil, options: [])
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }
}

enum ExportError: Error, LocalizedError {
    case sourceAndDestinationAreSame

    var errorDescription: String? {
        "Choose a different destination so the original file is preserved."
    }
}

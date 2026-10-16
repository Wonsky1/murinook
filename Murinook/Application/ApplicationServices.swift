import Foundation
import MurinookDomain
import MurinookUseCases
import MurinookStorage
import MurinookMacIntegration

/// The composition root owns lifetimes; each service keeps its own responsibility.
final class ApplicationServices {
    let diagnostics: DragDiagnostics
    let contentAccess = ContentAccessGate()
    let storage: StorageStack
    let preferences: PreferencesStore
    let history: HistoryStore
    let shelf: ShelfStore
    let queue: QueueStore
    let bookmarks: BookmarkAdapter
    let visuals: ContentVisualAdapter
    let imports: FileImportAdapter
    let writer: ClipboardContentWriter
    let monitor: ClipboardMonitor
    let dragMonitor: ExternalDragMonitor
    let permission: PastePermission
    let dispatcher: PasteDispatcher
    let providers: ContentItemProviderFactory

    init(directory: URL) throws {
        diagnostics = DragDiagnostics(directory: directory.appendingPathComponent("Diagnostics", isDirectory: true))
        diagnostics.event("application.services.start", fields: [
            "bundle_id": Bundle.main.bundleIdentifier ?? "unknown",
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"])
        storage = try StorageStack(directory: directory)
        preferences = PreferencesStore(repository: storage.preferences)
        history = HistoryStore(history: storage.history, collections: storage.collections,
            contents: storage.contents, preferences: preferences, accessGate: contentAccess)
        shelf = ShelfStore(repository: storage.shelf, contents: storage.contents, accessGate: contentAccess)
        queue = QueueStore()
        bookmarks = BookmarkAdapter(diagnostics: diagnostics)
        visuals = ContentVisualAdapter(bookmarks: bookmarks)
        imports = try FileImportAdapter(bookmarks: bookmarks, ownedFilesDirectory: directory.appending(path: "ImportedFiles"), diagnostics: diagnostics)
        let registry = ClipboardWriteRegistry()
        writer = ClipboardContentWriter(writeRegistry: registry)
        monitor = ClipboardMonitor(policy: ClipboardCapturePolicy(
            isEnabled: preferences.value.captureEnabled,
            excludedBundleIdentifiers: Set(preferences.value.excludedBundleIDs)), writeRegistry: registry, bookmarkAdapter: bookmarks)
        permission = PastePermission()
        dispatcher = PasteDispatcher(writer: writer, permission: permission,
            applicationBundleIdentifier: Bundle.main.bundleIdentifier ?? "wonsky.Murinook")
        dragMonitor = ExternalDragMonitor(diagnostics: diagnostics)
        providers = ContentItemProviderFactory()
    }
}

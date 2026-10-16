import MurinookUseCases
import MurinookStorage
import AppKit
import UniformTypeIdentifiers
import OSLog
import MurinookDomain
import MurinookMacIntegration

final class ShelfTransferController {
    private let services: ApplicationServices
    private let errors: ErrorPresenter
    private let logger = Logger(subsystem: "wonsky.Murinook", category: "ShelfDrop")
    private let dragItems: DragItemFactory
    private var hasDragLease = false
    private var activeDragAccess: [URL] = []
    private var preparedContent: [UUID: ClipContent] = [:]
    var requestCleanup: (() -> Void)?
    var dropped: ((Int) -> Void)?

    init(services: ApplicationServices, errors: ErrorPresenter) {
        self.services = services
        self.errors = errors
        dragItems = DragItemFactory(bookmarks: services.bookmarks)
    }

    func draggingItems(_ items: [ShelfItem]) async -> [NSDraggingItem] {
        services.diagnostics.event("shelf.outgoing.prepare", fields: ["selected_count": String(items.count)])
        do {
            return try await services.contentAccess.withAccess {
                itemsChanged()
                var result: [NSDraggingItem] = []
                for item in items {
                    let content: ClipContent
                    if let cached = preparedContent[item.contentID] { content = cached }
                    else {
                        content = try await services.storage.contents.get(item.contentID)
                        preparedContent[item.contentID] = content
                    }
                    result.append(contentsOf: try dragItems.makeItems(for: content))
                }
                services.diagnostics.event("shelf.outgoing.prepared", fields: ["drag_item_count": String(result.count)])
                return result
            }
        } catch {
            services.diagnostics.event("shelf.outgoing.prepare.failed", fields: services.diagnostics.errorFields(error))
            errors.show("Could not load item", detail: error.localizedDescription)
            return []
        }
    }

    func dragStarted(_ items: [ShelfItem]) -> Bool {
        services.diagnostics.event("shelf.outgoing.start", fields: ["selected_count": String(items.count)])
        releaseDragAccess()
        guard services.contentAccess.tryBeginAccess() else {
            services.diagnostics.event("shelf.outgoing.rejected", fields: ["reason": "storage_maintenance"])
            return false
        }
        hasDragLease = true
        do {
            for item in items {
                guard let content = preparedContent[item.contentID] else { throw CocoaError(.fileReadUnknown) }
                for file in content.files {
                    let url = try file.bookmark.map(services.bookmarks.resolve) ?? file.url
                    guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
                    if services.bookmarks.startAccessing(url) { activeDragAccess.append(url) }
                }
            }
            services.dragMonitor.isInternalDragActive = true
            return true
        } catch {
            services.diagnostics.event("shelf.outgoing.start.failed", fields: services.diagnostics.errorFields(error))
            releaseDragAccess()
            errors.show("Could not load item", detail: error.localizedDescription)
            return false
        }
    }

    func canAcceptDrop() -> Bool { !services.dragMonitor.isInternalDragActive }

    /// Captures the sender's pasteboard while the native drop grant is active.
    /// Real file URLs take priority over promises so ordinary files stay referenced originals.
    func acceptNative(_ pasteboard: NSPasteboard) -> Bool {
        let traceID = services.diagnostics.beginDrag(changeCount: pasteboard.changeCount)
        services.diagnostics.event("drop.capture.begin", fields: [
            "types": (pasteboard.types ?? []).map(\.rawValue).joined(separator: ","),
            "internal_drag": String(services.dragMonitor.isInternalDragActive), "app_active": String(NSApp.isActive)], dragID: traceID)
        guard canAcceptDrop() else {
            services.diagnostics.event("drop.capture.rejected", fields: ["reason": "internal_shelf_drag"], dragID: traceID)
            return false
        }
        do {
            let files = try services.imports.captureExternalFiles(from: pasteboard)
            if !files.isEmpty {
                services.diagnostics.event("drop.capture.files", fields: ["count": String(files.count),
                    "referenced_count": String(files.filter { !$0.isOwnedCopy }.count)], dragID: traceID)
                logger.notice("Native drop captured \(files.count) file references")
                importDropped(dragID: traceID) { [services] in try await services.imports.importExternalFiles(files) }
                return true
            }
            let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil)
                as? [NSFilePromiseReceiver] ?? []
            if !receivers.isEmpty {
                services.diagnostics.event("drop.capture.promises", fields: ["count": String(receivers.count)], dragID: traceID)
                logger.notice("Native drop captured \(receivers.count) file promises")
                guard services.contentAccess.tryBeginAccess() else {
                    services.diagnostics.event("drop.capture.rejected", fields: ["reason": "storage_maintenance"], dragID: traceID)
                    return false
                }
                let batch: PromiseReceiveBatch
                do { batch = try services.imports.beginReceivingPromises(receivers) }
                catch { services.contentAccess.endAccess(); throw error }
                importDropped(dragID: traceID) { [services] in
                    defer { services.contentAccess.endAccess() }
                    return try await batch.value().map { file in
                        ClipContent(files: [FileReference(url: file.url, bookmark: file.bookmark,
                            isOwnedCopy: file.isOwnedCopy, byteCount: file.byteCount)])
                    }
                }
                return true
            }
            // Snapshot provider data before AppKit can clear or reuse this pasteboard.
            let providers = snapshotProviders(from: pasteboard)
            guard !providers.isEmpty else {
                services.diagnostics.event("drop.capture.rejected", fields: ["reason": "no_readable_payload"], dragID: traceID)
                logger.notice("Native drop had no readable payload")
                return false
            }
            services.diagnostics.event("drop.capture.providers", fields: ["count": String(providers.count)], dragID: traceID)
            importDropped(dragID: traceID) { [services] in try await services.imports.importProviders(providers) }
            return true
        } catch {
            services.diagnostics.event("drop.capture.failed", fields: services.diagnostics.errorFields(error), dragID: traceID)
            logger.error("Native drop capture failed: \(error.localizedDescription, privacy: .private)")
            errors.show("Could not add dropped items", detail: error.localizedDescription)
            return false
        }
    }

    private func snapshotProviders(from pasteboard: NSPasteboard) -> [NSItemProvider] {
        (pasteboard.pasteboardItems ?? []).compactMap { item in
            let privateTypes: Set<String> = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
            guard item.types.allSatisfy({ !privateTypes.contains($0.rawValue) }) else { return nil }
            let provider = NSItemProvider()
            for type in item.types {
                guard let data = item.data(forType: type), !data.isEmpty else { continue }
                provider.registerDataRepresentation(forTypeIdentifier: type.rawValue, visibility: .all) { completion in
                    completion(data, nil)
                    return nil
                }
            }
            return provider.registeredTypeIdentifiers.isEmpty ? nil : provider
        }
    }

    private func importDropped(dragID: String, _ load: @escaping @MainActor () async throws -> [ClipContent]) {
        services.diagnostics.event("drop.import.scheduled", dragID: dragID)
        Task {
            await services.contentAccess.withAccess {
                services.diagnostics.event("drop.import.access_acquired", dragID: dragID)
                defer { requestCleanup?() }
                do {
                    let contents = try await load()
                    services.diagnostics.event("drop.import.loaded", fields: ["content_count": String(contents.count),
                        "shelf_loaded": String(services.shelf.isLoaded), "shelf_count": String(services.shelf.items.count)], dragID: dragID)
                    guard !contents.isEmpty else {
                        services.diagnostics.event("drop.import.empty", dragID: dragID)
                        errors.show("No supported items were dropped"); return
                    }
                    var succeeded = false
                    for (index, content) in contents.enumerated() {
                        let previous = services.shelf.items.count
                        services.diagnostics.event("drop.visual.begin", fields: ["index": String(index),
                            "file_count": String(content.files.count)], dragID: dragID)
                        let decorated = await services.visuals.addingVisuals(to: content)
                        services.diagnostics.event("drop.visual.finished", fields: ["index": String(index),
                            "has_icon": String(decorated.iconData != nil)], dragID: dragID)
                        await services.shelf.add(content: decorated)
                        services.diagnostics.event("drop.shelf.saved", fields: ["index": String(index),
                            "before": String(previous), "after": String(services.shelf.items.count),
                            "store_error": services.shelf.error.map { String(describing: $0) } ?? "none"], dragID: dragID)
                        succeeded = succeeded || services.shelf.items.count > previous
                    }
                    logger.notice("Drop import saved: \(succeeded)")
                    services.diagnostics.event("drop.import.finished", fields: ["succeeded": String(succeeded),
                        "item_count": String(services.shelf.items.count)], dragID: dragID)
                    if succeeded { dropped?(services.shelf.items.count) }
                } catch {
                    services.diagnostics.event("drop.import.failed", fields: services.diagnostics.errorFields(error), dragID: dragID)
                    errors.show("Could not add dropped items", detail: error.localizedDescription)
                }
            }
        }
    }

    func dragCompleted(_ item: ShelfItem, succeeded: Bool) {
        services.diagnostics.event("shelf.outgoing.completed", fields: ["item_id": item.id.uuidString,
            "succeeded": String(succeeded), "auto_remove": String(services.preferences.value.autoRemoveShelfItems)])
        releaseDragAccess()
        services.dragMonitor.isInternalDragActive = false
        if succeeded && services.preferences.value.autoRemoveShelfItems {
            Task { await services.shelf.completeTransfer([item.id]) }
        }
    }

    func itemsChanged() {
        let retained = Set(services.shelf.items.map(\.contentID))
        preparedContent = preparedContent.filter { retained.contains($0.key) }
    }

    private func releaseDragAccess() {
        activeDragAccess.forEach(services.bookmarks.stopAccessing)
        activeDragAccess.removeAll()
        if hasDragLease { hasDragLease = false; services.contentAccess.endAccess() }
    }
}

import AppKit
import MurinookDomain
import OSLog
import SwiftUI

@MainActor
struct ShelfDragHandle: NSViewRepresentable {
    let items: [ShelfItem]
    let makeDraggingItems: @MainActor ([ShelfItem]) async -> [NSDraggingItem]
    let dragStarted: @MainActor ([ShelfItem]) -> Bool
    let dragCompleted: (ShelfItem, Bool) -> Void
    let clicked: (NSEvent) -> Void

    func makeNSView(context: Context) -> ShelfDragSourceView {
        let view = ShelfDragSourceView()
        configure(view)
        return view
    }

    func updateNSView(_ view: ShelfDragSourceView, context: Context) { configure(view) }

    private func configure(_ view: ShelfDragSourceView) {
        view.makeDraggingItems = makeDraggingItems
        view.dragStarted = dragStarted
        view.dragCompleted = dragCompleted
        view.clicked = clicked
        view.prepare(items)
    }
}

/// Loads writers before the gesture, so mouseDragged starts an AppKit session synchronously.
@MainActor
final class ShelfDragSourceView: NSView, NSDraggingSource {
    var makeDraggingItems: @MainActor ([ShelfItem]) async -> [NSDraggingItem] = { _ in [] }
    var dragStarted: @MainActor ([ShelfItem]) -> Bool = { _ in true }
    var dragCompleted: (ShelfItem, Bool) -> Void = { _, _ in }
    var clicked: (NSEvent) -> Void = { _ in }

    private var items: [ShelfItem] = []
    private var nativeItems: [NSDraggingItem] = []
    private var preparation: Task<Void, Never>?
    private var loadToken = UUID()
    private var mouseDownEvent: NSEvent?
    private var activeItems: [ShelfItem] = []
    private var isDragging = false
    private let logger = Logger(subsystem: "wonsky.Murinook", category: "ShelfDrag")

    func prepare(_ items: [ShelfItem], force: Bool = false) {
        guard !isDragging, force || items.map(\.contentID) != self.items.map(\.contentID) else { return }
        self.items = items
        nativeItems = []
        preparation?.cancel()
        let token = UUID()
        loadToken = token
        preparation = Task { @MainActor [weak self] in
            guard let self else { return }
            let writers = await makeDraggingItems(items)
            guard !Task.isCancelled, token == loadToken else { return }
            nativeItems = writers
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging, let downEvent = mouseDownEvent, !nativeItems.isEmpty else { return }
        let point = convert(event.locationInWindow, from: nil)
        let origin = convert(downEvent.locationInWindow, from: nil)
        guard hypot(point.x - origin.x, point.y - origin.y) >= 4, dragStarted(items) else { return }
        isDragging = true
        activeItems = items
        for item in nativeItems {
            item.draggingFrame = NSRect(x: point.x - 24, y: point.y - 24, width: 48, height: 48)
        }
        logger.notice("Shelf drag session started")
        beginDraggingSession(with: nativeItems, event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging { clicked(event) }
        mouseDownEvent = nil
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        logger.notice("Shelf drag session ended; accepted: \(!operation.isEmpty)")
        activeItems.forEach { dragCompleted($0, !operation.isEmpty) }
        activeItems = []
        mouseDownEvent = nil
        isDragging = false
        prepare(items, force: true)
    }
}

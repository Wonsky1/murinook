import AppKit
import MurinookDomain
import UniformTypeIdentifiers

public struct ShelfPlacement: Equatable {
    public var side: ShelfSide
    public var offset: Double
    public init(side: ShelfSide, offset: Double) { self.side = side; self.offset = min(max(offset, 0), 1) }
}

public struct ShelfActions {
    public var draggingItems: @MainActor ([ShelfItem]) async -> [NSDraggingItem]
    public var dragStarted: @MainActor ([ShelfItem]) -> Bool
    public var preview: (ShelfItem) -> Void
    public var dragCompleted: (ShelfItem, Bool) -> Void
    public var hide: () -> Void
    public var close: () -> Void

    public init(draggingItems: @escaping @MainActor ([ShelfItem]) async -> [NSDraggingItem] = { _ in [] },
                dragStarted: @escaping @MainActor ([ShelfItem]) -> Bool = { _ in true },
                preview: @escaping (ShelfItem) -> Void = { _ in }, hide: @escaping () -> Void = {},
                close: @escaping () -> Void = {}, dragCompleted: @escaping (ShelfItem, Bool) -> Void = { _, _ in }) {
        self.draggingItems = draggingItems
        self.dragStarted = dragStarted
        self.preview = preview; self.dragCompleted = dragCompleted; self.hide = hide; self.close = close
    }
}

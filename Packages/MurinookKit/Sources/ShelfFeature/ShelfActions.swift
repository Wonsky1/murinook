import AppKit
import MurinookDomain
import UniformTypeIdentifiers

public struct ShelfActions {
    public var draggingItems: @MainActor ([ShelfItem]) async -> [NSDraggingItem]
    public var dragStarted: @MainActor ([ShelfItem]) -> Bool
    public var preview: (ShelfItem) -> Void
    public var dragCompleted: ([ShelfItem], Bool) -> Void
    public var hide: () -> Void
    public var close: () -> Void

    public init(draggingItems: @escaping @MainActor ([ShelfItem]) async -> [NSDraggingItem] = { _ in [] },
                dragStarted: @escaping @MainActor ([ShelfItem]) -> Bool = { _ in true },
                preview: @escaping (ShelfItem) -> Void = { _ in }, hide: @escaping () -> Void = {},
                close: @escaping () -> Void = {}, dragCompleted: @escaping ([ShelfItem], Bool) -> Void = { _, _ in }) {
        self.draggingItems = draggingItems
        self.dragStarted = dragStarted
        self.preview = preview; self.dragCompleted = dragCompleted; self.hide = hide; self.close = close
    }
}

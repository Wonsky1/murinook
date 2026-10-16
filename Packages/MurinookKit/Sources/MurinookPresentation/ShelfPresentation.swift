/// Visibility rules independent of windows, pointer geometry and persisted contents.
public struct ShelfPresentation: Sendable {
    public enum Mode: Sendable { case hidden, collapsed, expanded }
    public private(set) var mode: Mode
    private var itemCount: Int
    private var beforeDrag: Mode?
    private var receivedDrop = false
    private var manuallyHidden = false

    public init(itemCount: Int = 0) {
        self.itemCount = itemCount
        mode = itemCount > 0 ? .collapsed : .hidden
    }

    public mutating func externalDragStarted() {
        guard beforeDrag == nil else { return }
        beforeDrag = mode
        manuallyHidden = false
        receivedDrop = false
        mode = .expanded
    }

    public mutating func externalDragEnded() {
        guard let previous = beforeDrag else { return }
        beforeDrag = nil
        if !receivedDrop { mode = previous }
        if itemCount == 0 { mode = .hidden }
    }

    public mutating func dropSucceeded(itemCount: Int) {
        self.itemCount = itemCount
        receivedDrop = true
        mode = manuallyHidden ? (itemCount > 0 ? .collapsed : .hidden)
            : (itemCount > 0 || beforeDrag != nil ? .expanded : .hidden)
    }

    public mutating func itemsChanged(count: Int) {
        let wasEmpty = itemCount == 0
        itemCount = count
        if count == 0 && (mode == .collapsed || beforeDrag == nil) { mode = .hidden }
        if wasEmpty && count > 0 && mode == .hidden {
            mode = manuallyHidden ? .collapsed : .expanded
        }
    }

    public mutating func restore() {
        manuallyHidden = false
        mode = itemCount > 0 || beforeDrag != nil ? .expanded : .hidden
    }
    public mutating func hide() {
        manuallyHidden = true
        mode = itemCount > 0 ? .collapsed : .hidden
        if beforeDrag != nil { beforeDrag = mode }
    }
}

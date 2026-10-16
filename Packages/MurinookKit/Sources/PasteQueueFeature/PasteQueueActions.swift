import MurinookDomain

public struct PasteQueueActions {
    public var pasteNext: (QueueEntry) -> Void
    public var pasteNextPlainText: (QueueEntry) -> Void
    public var copy: (QueueEntry) -> Void
    public var close: () -> Void
    public init(pasteNext: @escaping (QueueEntry) -> Void = { _ in }, copy: @escaping (QueueEntry) -> Void = { _ in },
                close: @escaping () -> Void = {}, pasteNextPlainText: ((QueueEntry) -> Void)? = nil) {
        self.pasteNext = pasteNext; self.pasteNextPlainText = pasteNextPlainText ?? pasteNext
        self.copy = copy; self.close = close
    }
}

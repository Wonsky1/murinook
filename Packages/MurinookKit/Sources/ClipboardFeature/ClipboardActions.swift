import Foundation
import MurinookDomain

public struct QuickAccessActions {
    public var paste: (Clip) -> Void
    public var copy: (Clip) -> Void
    public var pastePlain: (Clip) -> Void
    public var addToShelf: (Clip) -> Void
    public var addToQueue: (Clip) -> Void
    public var openLibrary: () -> Void
    public var openHistorySettings: () -> Void
    public var close: () -> Void

    public init(paste: @escaping (Clip) -> Void = { _ in }, copy: @escaping (Clip) -> Void = { _ in },
                pastePlain: @escaping (Clip) -> Void = { _ in }, addToShelf: @escaping (Clip) -> Void = { _ in },
                addToQueue: @escaping (Clip) -> Void = { _ in }, openLibrary: @escaping () -> Void = {},
                openHistorySettings: @escaping () -> Void = {}, close: @escaping () -> Void = {}) {
        self.paste = paste; self.copy = copy; self.pastePlain = pastePlain
        self.addToShelf = addToShelf; self.addToQueue = addToQueue
        self.openLibrary = openLibrary; self.openHistorySettings = openHistorySettings; self.close = close
    }
}

public struct LibraryActions {
    public var copy: (Clip) -> Void
    public var paste: (Clip) -> Void
    public var pastePlain: (Clip) -> Void
    public var addToShelf: (Clip) -> Void
    public var addToQueue: (Clip) -> Void
    public var preview: (Clip) -> Void
    public var reveal: (Clip) -> Void
    public var export: (Set<UUID>) -> Void
    public var loadContent: (UUID) async -> ClipContent?
    public var showShelf: () -> Void
    public var showSettings: () -> Void
    public var manageRetention: () -> Void
    public var showUpdates: () -> Void
    public var close: () -> Void

    public init(copy: @escaping (Clip) -> Void = { _ in }, paste: @escaping (Clip) -> Void = { _ in },
                pastePlain: @escaping (Clip) -> Void = { _ in }, addToShelf: @escaping (Clip) -> Void = { _ in },
                addToQueue: @escaping (Clip) -> Void = { _ in }, preview: @escaping (Clip) -> Void = { _ in },
                reveal: @escaping (Clip) -> Void = { _ in }, export: @escaping (Set<UUID>) -> Void = { _ in },
                loadContent: @escaping (UUID) async -> ClipContent? = { _ in nil },
                showShelf: @escaping () -> Void = {}, showSettings: @escaping () -> Void = {},
                manageRetention: @escaping () -> Void = {},
                showUpdates: @escaping () -> Void = {},
                close: @escaping () -> Void = {}) {
        self.copy = copy; self.paste = paste; self.pastePlain = pastePlain
        self.addToShelf = addToShelf; self.addToQueue = addToQueue
        self.preview = preview; self.reveal = reveal; self.export = export; self.loadContent = loadContent
        self.showShelf = showShelf; self.showSettings = showSettings; self.close = close
        self.manageRetention = manageRetention
        self.showUpdates = showUpdates
    }
}

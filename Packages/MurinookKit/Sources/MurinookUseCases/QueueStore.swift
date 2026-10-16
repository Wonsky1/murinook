import Foundation
import Observation
import MurinookDomain

/// Session-local ordering for paste actions. The app decides when a dispatched paste advances this queue.
@MainActor @Observable public final class QueueStore {
    public private(set) var entries: [QueueEntry] = []
    public var retainedContentIDs: Set<UUID> { Set(entries.map(\.contentID)) }
    public var next: QueueEntry? { entries.first }
    public init() {}
    public func add(contentID: UUID, title: String, kind: ClipKind) { entries.append(QueueEntry(contentID: contentID, title: title, kind: kind)) }
    public func remove(_ id: UUID) { entries.removeAll { $0.id == id } }
    public func move(from: Int, to: Int) { guard entries.indices.contains(from), (0...entries.count).contains(to), from != to else { return }; let value = entries.remove(at: from); entries.insert(value, at: min(to, entries.count)) }
    public func skip() { if !entries.isEmpty { entries.removeFirst() } }
    public func clear() { entries.removeAll() }
}

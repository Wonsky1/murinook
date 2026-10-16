import Foundation
public struct QueueEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var contentID: UUID
    public var title: String
    public var kind: ClipKind
    public init(id: UUID = UUID(), contentID: UUID, title: String, kind: ClipKind) { self.id = id; self.contentID = contentID; self.title = title; self.kind = kind }
}

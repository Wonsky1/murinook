import Foundation
public struct ShelfItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var contentID: UUID
    public var iconData: Data?
    public var title: String
    public var kind: ClipKind
    public var createdAt: Date
    public var groupID: UUID?
    public init(id: UUID = UUID(), contentID: UUID, title: String, kind: ClipKind, createdAt: Date = .now, groupID: UUID? = nil, iconData: Data? = nil) {
        self.id = id; self.contentID = contentID; self.iconData = iconData; self.title = title; self.kind = kind; self.createdAt = createdAt; self.groupID = groupID
    }
}

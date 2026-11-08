import Foundation
public struct ShelfItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var contentID: UUID
    public var iconData: Data?
    public var title: String
    public var kind: ClipKind
    public var createdAt: Date
    public var groupID: UUID?
    public var isLocked: Bool

    public init(id: UUID = UUID(), contentID: UUID, title: String, kind: ClipKind, createdAt: Date = .now,
                groupID: UUID? = nil, iconData: Data? = nil, isLocked: Bool = false) {
        self.id = id; self.contentID = contentID; self.iconData = iconData; self.title = title
        self.kind = kind; self.createdAt = createdAt; self.groupID = groupID; self.isLocked = isLocked
    }

    private enum CodingKeys: String, CodingKey { case id, contentID, iconData, title, kind, createdAt, groupID, isLocked }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decode(UUID.self, forKey: .id),
                  contentID: try container.decode(UUID.self, forKey: .contentID),
                  title: try container.decode(String.self, forKey: .title),
                  kind: try container.decode(ClipKind.self, forKey: .kind),
                  createdAt: try container.decode(Date.self, forKey: .createdAt),
                  groupID: try container.decodeIfPresent(UUID.self, forKey: .groupID),
                  iconData: try container.decodeIfPresent(Data.self, forKey: .iconData),
                  isLocked: try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(contentID, forKey: .contentID)
        try container.encodeIfPresent(iconData, forKey: .iconData)
        try container.encode(title, forKey: .title)
        try container.encode(kind, forKey: .kind)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(groupID, forKey: .groupID)
        try container.encode(isLocked, forKey: .isLocked)
    }
}

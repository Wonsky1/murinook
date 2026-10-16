import Foundation

public struct SourceApplication: Codable, Hashable, Sendable {
    public var name: String
    public var bundleIdentifier: String?
    public init(name: String, bundleIdentifier: String? = nil) { self.name = name; self.bundleIdentifier = bundleIdentifier }
}

public struct Clip: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var contentID: UUID
    public var iconData: Data?
    public var title: String
    public var preview: String
    public var searchText: String?
    public var kind: ClipKind
    public var source: SourceApplication
    public var createdAt: Date
    public var lastCopiedAt: Date
    public var isPinned: Bool
    public var collectionIDs: Set<UUID>
    public var tags: [String]
    public var note: String
    public var byteCount: Int
    public var fingerprint: String

    public init(id: UUID = UUID(), contentID: UUID, title: String? = nil, preview: String = "", searchText: String? = nil, kind: ClipKind, source: SourceApplication, createdAt: Date = .now, lastCopiedAt: Date? = nil, isPinned: Bool = false, collectionIDs: Set<UUID> = [], tags: [String] = [], note: String = "", byteCount: Int = 0, fingerprint: String = "", iconData: Data? = nil) {
        self.id = id; self.contentID = contentID; self.iconData = iconData; self.title = title ?? preview; self.preview = preview; self.searchText = searchText; self.kind = kind; self.source = source
        self.createdAt = createdAt; self.lastCopiedAt = lastCopiedAt ?? createdAt; self.isPinned = isPinned; self.collectionIDs = collectionIDs
        self.tags = tags; self.note = note; self.byteCount = byteCount; self.fingerprint = fingerprint
    }
}

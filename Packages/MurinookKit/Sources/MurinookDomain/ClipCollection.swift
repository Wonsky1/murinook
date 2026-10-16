import Foundation
public struct ClipCollection: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var createdAt: Date
    public init(id: UUID = UUID(), name: String, colorHex: String = "#6E7BFF", createdAt: Date = .now) { self.id = id; self.name = name; self.colorHex = colorHex; self.createdAt = createdAt }
}

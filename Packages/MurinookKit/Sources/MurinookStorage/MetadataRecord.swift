import Foundation
import MurinookDomain
import SwiftData

@Model final class ClipRecord {
    @Attribute(.unique) var id: String
    var lastCopiedAt: Date
    var kindRawValue: String
    var fingerprint: String
    var searchText: String?
    var payload: Data
    init(_ value: Clip, payload: Data) {
        id = value.id.uuidString
        lastCopiedAt = value.lastCopiedAt
        kindRawValue = value.kind.rawValue
        fingerprint = value.fingerprint
        searchText = value.searchText
        self.payload = payload
    }
    func update(_ value: Clip, payload encoded: Data) {
        guard payload != encoded else { return }
        lastCopiedAt = value.lastCopiedAt
        kindRawValue = value.kind.rawValue
        fingerprint = value.fingerprint
        searchText = value.searchText
        payload = encoded
    }
    func decode() throws -> Clip { try JSONDecoder().decode(Clip.self, from: payload) }
}

@Model final class CollectionRecord {
    @Attribute(.unique) var id: String
    var name: String
    var colorHex: String
    var createdAt: Date
    var payload: Data
    init(_ value: ClipCollection, payload: Data) {
        id = value.id.uuidString; name = value.name; colorHex = value.colorHex; createdAt = value.createdAt
        self.payload = payload
    }
    func update(_ value: ClipCollection, payload encoded: Data) {
        guard payload != encoded else { return }
        name = value.name; colorHex = value.colorHex; createdAt = value.createdAt
        payload = encoded
    }
    func decode() throws -> ClipCollection { try JSONDecoder().decode(ClipCollection.self, from: payload) }
}

@Model final class ShelfRecord {
    @Attribute(.unique) var id: String
    var position: Int
    var createdAt: Date
    var kindRawValue: String
    var groupID: String?
    var payload: Data
    init(_ value: ShelfItem, position: Int, payload: Data) {
        id = value.id.uuidString; self.position = position; createdAt = value.createdAt; kindRawValue = value.kind.rawValue
        groupID = value.groupID?.uuidString; self.payload = payload
    }
    func update(_ value: ShelfItem, position: Int, payload encoded: Data) {
        guard payload != encoded || self.position != position else { return }
        self.position = position; createdAt = value.createdAt; kindRawValue = value.kind.rawValue
        groupID = value.groupID?.uuidString; payload = encoded
    }
    func decode() throws -> ShelfItem { try JSONDecoder().decode(ShelfItem.self, from: payload) }
}

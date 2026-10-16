import Foundation
import MurinookDomain
import SwiftData

@ModelActor actor MetadataDatabase {
    func loadClips() throws -> [Clip] {
        let request = FetchDescriptor<ClipRecord>(sortBy: [SortDescriptor(\.lastCopiedAt, order: .reverse)])
        return try modelContext.fetch(request).map { try $0.decode() }
    }
    func saveClips(_ clips: [Clip]) throws {
        let encodedValues = try clips.map { ($0, try JSONEncoder().encode($0)) }
        let records = try modelContext.fetch(FetchDescriptor<ClipRecord>())
        let incoming = Dictionary(uniqueKeysWithValues: clips.map { ($0.id.uuidString, $0) })
        for record in records where incoming[record.id] == nil { modelContext.delete(record) }
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for (clip, payload) in encodedValues {
            if let record = byID[clip.id.uuidString] {
                if try record.decode() != clip { record.update(clip, payload: payload) }
            }
            else { modelContext.insert(ClipRecord(clip, payload: payload)) }
        }
        try modelContext.save()
    }
    func loadCollections() throws -> [ClipCollection] {
        let request = FetchDescriptor<CollectionRecord>(sortBy: [SortDescriptor(\.createdAt)])
        return try modelContext.fetch(request).map { try $0.decode() }
    }
    func saveCollections(_ values: [ClipCollection]) throws {
        let encodedValues = try values.map { ($0, try JSONEncoder().encode($0)) }
        let records = try modelContext.fetch(FetchDescriptor<CollectionRecord>())
        let incoming = Dictionary(uniqueKeysWithValues: values.map { ($0.id.uuidString, $0) })
        for record in records where incoming[record.id] == nil { modelContext.delete(record) }
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for (value, payload) in encodedValues {
            if let record = byID[value.id.uuidString] {
                if try record.decode() != value { record.update(value, payload: payload) }
            }
            else { modelContext.insert(CollectionRecord(value, payload: payload)) }
        }
        try modelContext.save()
    }
    func loadShelf() throws -> [ShelfItem] {
        let request = FetchDescriptor<ShelfRecord>(sortBy: [SortDescriptor(\.position)])
        return try modelContext.fetch(request).map { try $0.decode() }
    }
    func saveShelf(_ values: [ShelfItem]) throws {
        let encodedValues = try values.map { ($0, try JSONEncoder().encode($0)) }
        let records = try modelContext.fetch(FetchDescriptor<ShelfRecord>())
        let incoming = Dictionary(uniqueKeysWithValues: values.map { ($0.id.uuidString, $0) })
        for record in records where incoming[record.id] == nil { modelContext.delete(record) }
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for (position, pair) in encodedValues.enumerated() {
            let (value, payload) = pair
            if let record = byID[value.id.uuidString] {
                if try record.decode() != value || record.position != position {
                    record.update(value, position: position, payload: payload)
                }
            }
            else { modelContext.insert(ShelfRecord(value, position: position, payload: payload)) }
        }
        try modelContext.save()
    }
}

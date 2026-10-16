import Foundation
import MurinookDomain
import MurinookUseCases

@MainActor final class SwiftDataHistoryRepository: HistoryRepository {
    private let database: MetadataDatabase
    init(database: MetadataDatabase) { self.database = database }
    func load() async throws -> [Clip] { try await database.loadClips() }
    func save(_ clips: [Clip]) async throws { try await database.saveClips(clips) }
}

@MainActor final class SwiftDataCollectionRepository: CollectionRepository {
    private let database: MetadataDatabase
    init(database: MetadataDatabase) { self.database = database }
    func load() async throws -> [ClipCollection] { try await database.loadCollections() }
    func save(_ collections: [ClipCollection]) async throws { try await database.saveCollections(collections) }
}

@MainActor final class SwiftDataShelfRepository: ShelfRepository {
    private let database: MetadataDatabase
    init(database: MetadataDatabase) { self.database = database }
    func load() async throws -> [ShelfItem] { try await database.loadShelf() }
    func save(_ items: [ShelfItem]) async throws { try await database.saveShelf(items) }
}

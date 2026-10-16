import Foundation
import MurinookDomain
import MurinookUseCases
import SwiftData

@MainActor public final class StorageStack {
    public let history: any HistoryRepository
    public let collections: any CollectionRepository
    public let shelf: any ShelfRepository
    public let contents: any ContentRepository
    public let preferences: any PreferencesRepository
    private let fileContents: FileContentRepository

    public init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let preferenceRepository = try FilePreferencesRepository(directory: directory)
        let schema = Schema(versionedSchema: MurinookSchemaV1.self)
        let configuration = ModelConfiguration("Murinook", schema: schema, url: directory.appendingPathComponent("Metadata.store"), allowsSave: true)
        let container = try ModelContainer(for: schema, migrationPlan: MurinookMigrationPlan.self, configurations: [configuration])
        let database = MetadataDatabase(modelContainer: container)
        history = SwiftDataHistoryRepository(database: database)
        collections = SwiftDataCollectionRepository(database: database)
        shelf = SwiftDataShelfRepository(database: database)
        let fileContents = try FileContentRepository(directory: directory)
        self.fileContents = fileContents
        contents = fileContents
        preferences = preferenceRepository
    }

    /// Prunes metadata-unreferenced payloads at startup, before capture or queue activity begins.
    public func pruneUnreferencedContents(
        retaining contentIDs: Set<UUID>,
        protectedImportURLs: Set<URL> = []
    ) async throws {
        try await fileContents.pruneUnreferenced(retaining: contentIDs, protectedImportURLs: protectedImportURLs)
    }
}

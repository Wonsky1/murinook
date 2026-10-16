import Foundation
import SwiftData

public enum MurinookSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] { [ClipRecord.self, CollectionRecord.self, ShelfRecord.self] }
}

enum MurinookMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [MurinookSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

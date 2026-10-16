import Foundation
import MurinookDomain

@MainActor public protocol HistoryRepository { func load() async throws -> [Clip]; func save(_ clips: [Clip]) async throws }
@MainActor public protocol CollectionRepository { func load() async throws -> [ClipCollection]; func save(_ collections: [ClipCollection]) async throws }
@MainActor public protocol ShelfRepository { func load() async throws -> [ShelfItem]; func save(_ items: [ShelfItem]) async throws }
@MainActor public protocol ContentRepository { func put(_ content: ClipContent, id: UUID) async throws; func get(_ id: UUID) async throws -> ClipContent; func remove(_ ids: Set<UUID>) async throws }
@MainActor public protocol PreferencesRepository { func load() -> AppPreferences; func save(_ value: AppPreferences) throws }

public enum UseCaseError: Error, Equatable, Sendable {
    case persistence(operation: String)
    case contentUnavailable

    /// Stable catalog key for UI-owned localization. Operation details remain available for diagnostics.
    public var localizationKey: String {
        switch self {
        case .persistence: "core.error.persistence"
        case .contentUnavailable: "core.error.contentUnavailable"
        }
    }
}

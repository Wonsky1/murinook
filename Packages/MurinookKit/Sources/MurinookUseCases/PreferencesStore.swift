import Foundation
import Observation
import MurinookDomain

@MainActor @Observable public final class PreferencesStore {
    public private(set) var value: AppPreferences
    public private(set) var errorMessage: String?
    public private(set) var error: UseCaseError?
    private let repository: any PreferencesRepository
    public init(repository: any PreferencesRepository) { self.repository = repository; self.value = repository.load() }
    /// Returns whether the new preferences were durably saved.
    @discardableResult
    public func update(_ change: (inout AppPreferences) -> Void) -> Bool {
        var next = value
        change(&next)
        next.shelfOffset = min(1, max(0, next.shelfOffset))
        next.retentionDays = max(0, next.retentionDays)
        next.maxHistoryItems = next.maxHistoryItems == 0 ? 0 : max(1, next.maxHistoryItems)
        do { try repository.save(next); value = next; error = nil; errorMessage = nil; return true }
        catch { self.error = .persistence(operation: "preferences.save"); errorMessage = "Could not save preferences."; return false }
    }
}

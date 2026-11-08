import XCTest
import MurinookDomain
import MurinookUseCases

@MainActor
final class QueueAndPreferencesTests: XCTestCase {
    func testQueueIsOrderedAndOnlyAdvancesWhenExplicitlySkipped() {
        let queue = QueueStore()
        let first = QueueEntry(contentID: UUID(), title: "First", kind: .text)
        queue.add(contentID: first.contentID, title: first.title, kind: first.kind)
        queue.add(contentID: UUID(), title: "Second", kind: .image)
        XCTAssertEqual(queue.next?.title, "First")
        queue.move(from: 1, to: 0)
        XCTAssertEqual(queue.next?.title, "Second")
        queue.skip()
        XCTAssertEqual(queue.next?.title, "First")
    }

    func testMoveDownUsesFinalIndex() {
        let queue = QueueStore()
        queue.add(contentID: UUID(), title: "First", kind: .text)
        queue.add(contentID: UUID(), title: "Second", kind: .text)
        queue.add(contentID: UUID(), title: "Third", kind: .text)
        queue.move(from: 0, to: 1)
        XCTAssertEqual(queue.entries.map(\.title), ["Second", "First", "Third"])
    }

    func testPreferencesUseDefaultsAndKeepOldValueWhenSaveFails() throws {
        let repository = FailingPreferencesRepository()
        let store = PreferencesStore(repository: repository)
        XCTAssertTrue(store.value.captureEnabled)
        XCTAssertEqual(store.value.retentionDays, 30)
        XCTAssertEqual(store.value.maxHistoryItems, 5000)
        let previous = store.value
        repository.shouldFail = true
        store.update { $0.captureEnabled = false }
        XCTAssertEqual(store.value, previous)
        XCTAssertNotNil(store.error)
    }

    func testPreferencesAddedShelfAutomationDefaultsOnForOlderSavedValues() throws {
        let data = Data("{\"captureEnabled\":true,\"retentionDays\":30}".utf8)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)

        XCTAssertTrue(decoded.autoShowShelf)
        XCTAssertTrue(decoded.autoRemoveShelfItems)
        XCTAssertFalse(decoded.showsDockIcon)
        XCTAssertEqual(decoded.retentionDays, 30)
    }

    func testShelfPositionMigratesFromLegacyEdgeAndOffsetAndDefaultsUnlocked() throws {
        let data = Data("{\"shelfSide\":\"left\",\"shelfOffset\":0.23}".utf8)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)

        XCTAssertEqual(decoded.shelfPosition, ShelfPosition(x: 0, y: 0.23))
        XCTAssertFalse(decoded.shelfPositionLocked)
        XCTAssertEqual(decoded.shelfSide, .left)
        XCTAssertEqual(decoded.shelfOffset, 0.23)
    }

    func testShelfPositionAndLockRoundTripAndMalformedCoordinatesClamp() throws {
        let preferences = AppPreferences(shelfPosition: ShelfPosition(x: 0.35, y: 0.8), shelfPositionLocked: true)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(decoded.shelfPosition, ShelfPosition(x: 0.35, y: 0.8))
        XCTAssertTrue(decoded.shelfPositionLocked)

        let malformed = Data("{\"shelfPosition\":{\"x\":4,\"y\":-2}}".utf8)
        let clamped = try JSONDecoder().decode(AppPreferences.self, from: malformed)
        XCTAssertEqual(clamped.shelfPosition, ShelfPosition(x: 1, y: 0))

        XCTAssertEqual(ShelfPosition(x: .nan, y: .infinity), ShelfPosition(x: 0.5, y: 0.5))
    }

    func testPreferencesMigrationPreservesExplicitDockIconChoice() throws {
        let data = Data("{\"showsDockIcon\":true}".utf8)

        XCTAssertTrue(try JSONDecoder().decode(AppPreferences.self, from: data).showsDockIcon)
    }

    func testUnlimitedHistoryCountSurvivesInitializationAndCoding() throws {
        let preferences = AppPreferences(maxHistoryItems: 0)
        XCTAssertEqual(preferences.maxHistoryItems, 0)

        let decoded = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(decoded.maxHistoryItems, 0)
    }

    func testNegativeHistoryCountIsSanitizedAndZeroPersistsThroughStore() throws {
        XCTAssertEqual(AppPreferences(maxHistoryItems: -4).maxHistoryItems, 1)
        XCTAssertEqual(try JSONDecoder().decode(AppPreferences.self, from: Data("{\"maxHistoryItems\":-4}".utf8)).maxHistoryItems, 1)

        let repository = FailingPreferencesRepository()
        let store = PreferencesStore(repository: repository)
        XCTAssertTrue(store.update { $0.maxHistoryItems = 0 })
        XCTAssertEqual(store.value.maxHistoryItems, 0)
        XCTAssertEqual(repository.load().maxHistoryItems, 0)

        XCTAssertTrue(store.update { $0.maxHistoryItems = -4 })
        XCTAssertEqual(store.value.maxHistoryItems, 1)
    }
}

@MainActor
private final class FailingPreferencesRepository: PreferencesRepository {
    var shouldFail = false
    var value = AppPreferences()
    func load() -> AppPreferences { value }
    func save(_ value: AppPreferences) throws {
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
        self.value = value
    }
}

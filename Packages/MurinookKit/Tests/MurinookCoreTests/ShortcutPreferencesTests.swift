import Foundation
import XCTest
import MurinookDomain
import MurinookStorage
import MurinookUseCases

@MainActor
final class ShortcutPreferencesTests: XCTestCase {
    func testCustomBareKeyCombinationAndDisabledActionSurviveReopeningRepository() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PreferencesStore(repository: try FilePreferencesRepository(directory: directory))
        let bareKey = KeyCombination(keyCode: 80, modifiers: [])
        let chord = KeyCombination(keyCode: 0, modifiers: [.command, .option, .shift])

        XCTAssertTrue(store.update {
            $0.shortcuts[.quickAccess] = bareKey
            $0.shortcuts[.library] = chord
            $0.shortcuts.removeValue(forKey: .shelf)
        })

        let reopened = PreferencesStore(repository: try FilePreferencesRepository(directory: directory))
        XCTAssertEqual(reopened.value.shortcuts[.quickAccess], bareKey)
        XCTAssertEqual(reopened.value.shortcuts[.library], chord)
        XCTAssertNil(reopened.value.shortcuts[.shelf])
        XCTAssertEqual(reopened.value.shortcuts[.pasteNext], KeyCombination.defaults[.pasteNext])
    }

    func testFailedShortcutSaveReportsFailureAndPreservesPreviousBinding() {
        let store = PreferencesStore(repository: UnwritableShortcutPreferences())
        let previous = store.value.shortcuts

        XCTAssertFalse(store.update { $0.shortcuts[.quickAccess] = .init(keyCode: 80, modifiers: []) })
        XCTAssertEqual(store.value.shortcuts, previous)
        XCTAssertNotNil(store.error)
    }
}

@MainActor
private final class UnwritableShortcutPreferences: PreferencesRepository {
    func load() -> AppPreferences { AppPreferences() }
    func save(_ value: AppPreferences) throws { throw CocoaError(.fileWriteNoPermission) }
}

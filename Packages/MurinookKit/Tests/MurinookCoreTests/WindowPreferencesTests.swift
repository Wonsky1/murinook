import Foundation
import XCTest
import MurinookDomain
import MurinookStorage
import MurinookUseCases

final class WindowPreferencesTests: XCTestCase {
    func testLegacyPreferencesEnableMissingFeaturesAndPreserveExistingValues() throws {
        let stored = AppPreferences(
            retentionDays: 90,
            showsDockIcon: true,
            languageCode: "uk",
            shortcuts: [.quickAccess: KeyCombination(keyCode: 9, modifiers: [.command, .shift])]
        )
        var legacyJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        legacyJSON.removeValue(forKey: "windowManagementEnabled")
        legacyJSON.removeValue(forKey: "clipboardEnabled")
        legacyJSON.removeValue(forKey: "shelfEnabled")
        legacyJSON.removeValue(forKey: "shortcutDefaultsVersion")
        let data = try JSONSerialization.data(withJSONObject: legacyJSON)

        let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)

        XCTAssertTrue(preferences.windowManagementEnabled)
        XCTAssertTrue(preferences.clipboardEnabled)
        XCTAssertTrue(preferences.shelfEnabled)
        XCTAssertEqual(preferences.retentionDays, 90)
        XCTAssertTrue(preferences.showsDockIcon)
        XCTAssertEqual(preferences.languageCode, "uk")
        XCTAssertEqual(preferences.shortcuts[.quickAccess], KeyCombination(keyCode: 9, modifiers: [.command, .shift]))
        XCTAssertEqual(preferences.shortcuts[.windowLeftHalf], KeyCombination.windowDefaults[.windowLeftHalf])
    }

    func testExplicitlySavedDisabledFeatureChoicesSurviveDecoding() throws {
        let stored = AppPreferences(clipboardEnabled: false, shelfEnabled: false, windowManagementEnabled: false)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(stored))

        XCTAssertFalse(decoded.clipboardEnabled)
        XCTAssertFalse(decoded.shelfEnabled)
        XCTAssertFalse(decoded.windowManagementEnabled)
    }

    @MainActor
    func testWindowManagementOptInAndShortcutPersistAfterReopeningRepository() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PreferencesStore(repository: try FilePreferencesRepository(directory: directory))
        let shortcut = KeyCombination(keyCode: 123, modifiers: [.command, .option])

        XCTAssertTrue(store.update {
            $0.windowManagementEnabled = true
            $0.shortcuts[.windowLeftHalf] = shortcut
        })

        let reopened = PreferencesStore(repository: try FilePreferencesRepository(directory: directory))
        XCTAssertTrue(reopened.value.windowManagementEnabled)
        XCTAssertEqual(reopened.value.shortcuts[.windowLeftHalf], shortcut)
        XCTAssertEqual(reopened.value.shortcuts[.quickAccess], KeyCombination.defaults[.quickAccess])
    }

    @MainActor
    func testAllFeaturePreferencesAndCustomShortcutsPersistAfterReopeningRepository() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PreferencesStore(repository: try FilePreferencesRepository(directory: directory))
        let customShortcut = KeyCombination(keyCode: 80, modifiers: [.command])
        let customWindowShortcut = KeyCombination(keyCode: 79, modifiers: [.control, .shift])

        XCTAssertTrue(store.update {
            $0.captureEnabled = true
            $0.autoShowShelf = false
            $0.clipboardEnabled = false
            $0.shelfEnabled = false
            $0.windowManagementEnabled = false
            $0.shortcuts[.quickAccess] = customShortcut
            $0.shortcuts[.windowCenter] = customWindowShortcut
        })

        let reopened = PreferencesStore(repository: try FilePreferencesRepository(directory: directory))
        XCTAssertTrue(reopened.value.captureEnabled)
        XCTAssertFalse(reopened.value.autoShowShelf)
        XCTAssertFalse(reopened.value.clipboardEnabled)
        XCTAssertFalse(reopened.value.shelfEnabled)
        XCTAssertFalse(reopened.value.windowManagementEnabled)
        XCTAssertEqual(reopened.value.shortcuts[.quickAccess], customShortcut)
        XCTAssertEqual(reopened.value.shortcuts[.windowCenter], customWindowShortcut)
    }

    func testWindowShortcutDefaultsMatchRectangleRecommendedPreset() {
        let controlOption: ShortcutModifiers = [.control, .option]
        let displayShortcut: ShortcutModifiers = [.control, .option, .command]
        let expected: [ShortcutAction: KeyCombination] = [
            .windowLeftHalf: .init(keyCode: 123, modifiers: controlOption),
            .windowRightHalf: .init(keyCode: 124, modifiers: controlOption),
            .windowTopHalf: .init(keyCode: 126, modifiers: controlOption),
            .windowBottomHalf: .init(keyCode: 125, modifiers: controlOption),
            .windowTopLeft: .init(keyCode: 32, modifiers: controlOption),
            .windowTopRight: .init(keyCode: 34, modifiers: controlOption),
            .windowBottomLeft: .init(keyCode: 38, modifiers: controlOption),
            .windowBottomRight: .init(keyCode: 40, modifiers: controlOption),
            .windowFirstThird: .init(keyCode: 2, modifiers: controlOption),
            .windowCenterThird: .init(keyCode: 3, modifiers: controlOption),
            .windowLastThird: .init(keyCode: 5, modifiers: controlOption),
            .windowMaximize: .init(keyCode: 36, modifiers: controlOption),
            .windowCenter: .init(keyCode: 8, modifiers: controlOption),
            .windowRestore: .init(keyCode: 51, modifiers: controlOption),
            .windowNextDisplay: .init(keyCode: 124, modifiers: displayShortcut),
            .windowPreviousDisplay: .init(keyCode: 123, modifiers: displayShortcut)
        ]
        let expectedApplication: [ShortcutAction: KeyCombination] = [
            .quickAccess: .init(keyCode: 9, modifiers: [.command, .shift]),
            .library: .init(keyCode: 11, modifiers: [.control, .option]),
            .shelf: .init(keyCode: 1, modifiers: [.control, .option]),
            .pasteNext: .init(keyCode: 9, modifiers: [.control, .option])
        ]

        XCTAssertEqual(KeyCombination.windowDefaults, expected)
        XCTAssertEqual(KeyCombination.defaults.count, ShortcutAction.applicationActions.count + expected.count)
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: KeyCombination.defaults.filter { $0.key.windowAction == nil }),
            expectedApplication
        )
    }

    func testLegacyMigrationKeepsCustomBindingsAndSkipsConflictingPreset() throws {
        let conflict = KeyCombination.windowDefaults[.windowLeftHalf]!
        let custom = KeyCombination(keyCode: 80, modifiers: [.command])
        let stored = AppPreferences(shortcuts: [
            .quickAccess: conflict,
            .windowRightHalf: custom
        ])

        let migrated = try decodeLegacy(stored)

        XCTAssertEqual(migrated.shortcuts[.quickAccess], conflict)
        XCTAssertNil(migrated.shortcuts[.windowLeftHalf])
        XCTAssertEqual(migrated.shortcuts[.windowRightHalf], custom)
        XCTAssertEqual(migrated.shortcuts[.windowTopHalf], KeyCombination.windowDefaults[.windowTopHalf])
        XCTAssertTrue(migrated.windowManagementEnabled)
    }

    func testMigrationMarkerPreservesExplicitlyRemovedDefaultAcrossReopen() throws {
        var migrated = try decodeLegacy(AppPreferences(shortcuts: [:]))
        XCTAssertNotNil(migrated.shortcuts[.windowLeftHalf])

        migrated.shortcuts.removeValue(forKey: .windowLeftHalf)
        migrated.windowManagementEnabled = false
        let reopened = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(migrated))

        XCTAssertNil(reopened.shortcuts[.windowLeftHalf])
        XCTAssertFalse(reopened.windowManagementEnabled)
        XCTAssertNotNil(reopened.shortcuts[.windowRightHalf])
    }

    func testWindowShortcutMappingCoversEveryWindowActionAndKeepsExistingActionsSeparate() {
        let expectedMappings: [ShortcutAction: WindowAction] = [
            .windowLeftHalf: .leftHalf,
            .windowRightHalf: .rightHalf,
            .windowTopHalf: .topHalf,
            .windowBottomHalf: .bottomHalf,
            .windowTopLeft: .topLeft,
            .windowTopRight: .topRight,
            .windowBottomLeft: .bottomLeft,
            .windowBottomRight: .bottomRight,
            .windowFirstThird: .firstThird,
            .windowCenterThird: .centerThird,
            .windowLastThird: .lastThird,
            .windowMaximize: .maximize,
            .windowCenter: .center,
            .windowRestore: .restore,
            .windowNextDisplay: .nextDisplay,
            .windowPreviousDisplay: .previousDisplay
        ]

        XCTAssertEqual(WindowAction.allCases.count, expectedMappings.count)
        XCTAssertEqual(ShortcutAction.windowActions.count, expectedMappings.count)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: ShortcutAction.windowActions.compactMap { action in
            action.windowAction.map { (action, $0) }
        }), expectedMappings)
        XCTAssertEqual(ShortcutAction.applicationActions, [.quickAccess, .library, .shelf, .pasteNext])
        XCTAssertTrue(ShortcutAction.applicationActions.allSatisfy { $0.windowAction == nil })
        XCTAssertEqual(Set(ShortcutAction.windowActions.compactMap(\.windowAction)), Set(WindowAction.allCases))
        XCTAssertEqual(Set(KeyCombination.defaults.keys), Set(ShortcutAction.allCases))
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: KeyCombination.defaults.filter { $0.key.windowAction == nil }),
            [
                .quickAccess: .init(keyCode: 9, modifiers: [.command, .shift]),
                .library: .init(keyCode: 11, modifiers: [.control, .option]),
                .shelf: .init(keyCode: 1, modifiers: [.control, .option]),
                .pasteNext: .init(keyCode: 9, modifiers: [.control, .option])
            ]
        )
    }

    func testActiveShortcutsRespectIndependentFeatureSwitchesWithoutChangingStoredBindings() {
        var preferences = AppPreferences()
        let storedShortcuts = preferences.shortcuts

        XCTAssertTrue(preferences.clipboardEnabled)
        XCTAssertTrue(preferences.shelfEnabled)
        XCTAssertTrue(preferences.windowManagementEnabled)
        XCTAssertEqual(preferences.activeShortcuts, storedShortcuts)

        preferences.clipboardEnabled = false
        XCTAssertNil(preferences.activeShortcuts[.quickAccess])
        XCTAssertNil(preferences.activeShortcuts[.library])
        XCTAssertNil(preferences.activeShortcuts[.pasteNext])
        XCTAssertNotNil(preferences.activeShortcuts[.shelf])
        XCTAssertNotNil(preferences.activeShortcuts[.windowLeftHalf])

        preferences.clipboardEnabled = true
        preferences.shelfEnabled = false
        XCTAssertNotNil(preferences.activeShortcuts[.quickAccess])
        XCTAssertNil(preferences.activeShortcuts[.shelf])
        XCTAssertNotNil(preferences.activeShortcuts[.windowLeftHalf])

        preferences.shelfEnabled = true
        preferences.windowManagementEnabled = false
        XCTAssertNotNil(preferences.activeShortcuts[.quickAccess])
        XCTAssertNotNil(preferences.activeShortcuts[.shelf])
        XCTAssertNil(preferences.activeShortcuts[.windowLeftHalf])
        XCTAssertEqual(preferences.shortcuts, storedShortcuts)
    }

    private func decodeLegacy(_ preferences: AppPreferences) throws -> AppPreferences {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
        json.removeValue(forKey: "shortcutDefaultsVersion")
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(AppPreferences.self, from: data)
    }
}

import XCTest
@testable import SettingsFeature

@MainActor
final class SettingsNavigationTests: XCTestCase {
    func testSettingsOpensOnClipboardByDefault() {
        XCTAssertEqual(SettingsNavigation().selection, .clipboard)
    }

    func testInitialLegacyDestinationsRedirectToTheirFeatureTab() {
        for legacySection in [SettingsSection.history, .privacy, .shortcuts] {
            XCTAssertEqual(SettingsNavigation(selection: legacySection).selection, .clipboard)
        }

        XCTAssertEqual(SettingsNavigation(selection: .shelf).selection, .fileShelf)
    }

    func testChangingSelectionRedirectsLegacyDestinationsAndKeepsVisibleTabsSelectable() {
        let navigation = SettingsNavigation()

        navigation.selection = .privacy
        XCTAssertEqual(navigation.selection, .clipboard)
        navigation.selection = .shortcuts
        XCTAssertEqual(navigation.selection, .clipboard)
        navigation.selection = .history
        XCTAssertEqual(navigation.selection, .clipboard)
        navigation.selection = .shelf
        XCTAssertEqual(navigation.selection, .fileShelf)

        navigation.selection = .windowManagement
        XCTAssertEqual(navigation.selection, .windowManagement)
        navigation.selection = .updates
        XCTAssertEqual(navigation.selection, .updates)
        navigation.selection = .general
        XCTAssertEqual(navigation.selection, .general)
    }
}

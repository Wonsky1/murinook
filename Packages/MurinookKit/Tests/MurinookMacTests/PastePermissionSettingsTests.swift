import XCTest
import MurinookMacIntegration
@testable import SettingsFeature

final class PastePermissionSettingsTests: XCTestCase {
    func testSettingsPermissionStatusReadsTheInjectedLiveCheck() {
        var isGranted = false
        let actions = SettingsActions(hasPostEventAccess: { isGranted })

        XCTAssertFalse(actions.hasPostEventAccess())
        isGranted = true
        XCTAssertTrue(actions.hasPostEventAccess())
    }

    @MainActor
    func testGateStaysClosedUntilPostEventAccessIsGranted() {
        let permission = PastePermission(postEventAccessCheck: { false })

        XCTAssertFalse(permission.hasPostEventAccess)
    }

    @MainActor
    func testRequestReturnsPostEventPermissionGrantResult() {
        var promptCount = 0
        let permission = PastePermission(
            postEventAccessCheck: { false },
            postEventAccessRequest: {
                promptCount += 1
                return true
            }
        )

        XCTAssertTrue(permission.requestPostEventAccess())

        XCTAssertEqual(promptCount, 1)
    }
}

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

    @MainActor
    func testPermissionChecksReportChangedCapabilitiesWithoutTimerLogSpam() {
        var postEvent = false
        var accessibility = false
        var records: [PastePermissionDiagnostic] = []
        let permission = PastePermission(
            postEventAccessCheck: { postEvent },
            accessibilityTrustCheck: { accessibility },
            diagnostics: { records.append($0) }
        )

        XCTAssertFalse(permission.hasPostEventAccess)
        XCTAssertFalse(permission.hasPostEventAccess)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.last?.trigger, .statusChanged)

        accessibility = true
        XCTAssertFalse(permission.hasPostEventAccess, "AX trust must not bypass Post Event permission")
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.last?.postEventAccess, false)
        XCTAssertEqual(records.last?.accessibilityTrusted, true)

        postEvent = true
        XCTAssertTrue(permission.hasPostEventAccess)
        XCTAssertTrue(permission.hasPostEventAccess)
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records.last?.postEventAccess, true)
    }

    @MainActor
    func testExplicitCheckReportsFreshResultWithoutRequestingOrLatchingAccess() {
        var granted = true
        var requests = 0
        var records: [PastePermissionDiagnostic] = []
        let permission = PastePermission(
            postEventAccessCheck: { granted },
            postEventAccessRequest: { requests += 1; return true },
            accessibilityTrustCheck: { true },
            diagnostics: { records.append($0) }
        )

        XCTAssertTrue(permission.checkPostEventAccess())
        XCTAssertTrue(permission.checkPostEventAccess())
        granted = false
        XCTAssertFalse(permission.checkPostEventAccess())
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(records.map(\.trigger), [.explicitCheck, .explicitCheck, .explicitCheck])
        XCTAssertEqual(records.last?.postEventAccess, false)
        XCTAssertEqual(records.last?.accessibilityTrusted, true)
        XCTAssertTrue(records.allSatisfy { $0.requestResult == nil && $0.processIdentifier > 0 })
    }

    @MainActor
    func testRequestReportsReturnedResultSeparatelyFromActualPostEventReadback() {
        var requests = 0
        var records: [PastePermissionDiagnostic] = []
        let permission = PastePermission(
            postEventAccessCheck: { false },
            postEventAccessRequest: { requests += 1; return true },
            accessibilityTrustCheck: { true },
            diagnostics: { records.append($0) }
        )

        XCTAssertTrue(permission.requestPostEventAccess())
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.last?.trigger, .request)
        XCTAssertEqual(records.last?.requestResult, true)
        XCTAssertEqual(records.last?.postEventAccess, false)
        XCTAssertEqual(records.last?.accessibilityTrusted, true)
        XCTAssertFalse(permission.hasPostEventAccess)
        XCTAssertEqual(records.count, 1, "The following automatic read should not repeat the same snapshot")
    }
}

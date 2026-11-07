import CoreGraphics
import MurinookDomain
import XCTest
@testable import MurinookWindowManagement

@MainActor
final class WindowManagerTests: XCTestCase {
    private let original = CGRect(x: 120, y: 100, width: 640, height: 500)

    func testPermissionIsLiveAndDeniedExecutionNeverTouchesTarget() {
        let system = FakeWindowSystem()
        let manager = WindowManager(system: system)
        system.hasAccessibilityAccess = false
        XCTAssertFalse(manager.hasAccessibilityAccess)
        assertError(.accessibilityRequired) { try manager.execute(.leftHalf) }
        XCTAssertEqual(system.writeCount, 0)
        system.hasAccessibilityAccess = true
        XCTAssertTrue(manager.hasAccessibilityAccess)
        XCTAssertTrue(manager.requestAccessibilityAccess())
        XCTAssertEqual(system.requestCount, 1)
    }

    func testRestoreUsesOriginalFrameBeforeFirstSuccessfulAction() throws {
        let system = FakeWindowSystem()
        system.frame = original
        let manager = WindowManager(system: system)
        try manager.execute(.leftHalf)
        try manager.execute(.bottomRight)
        try manager.execute(.restore)
        XCTAssertEqual(system.frame, original)
    }

    func testFailedWriteRetainsRestoreFrameWhenWindowMovedPartially() throws {
        let system = FakeWindowSystem()
        system.frame = original
        let manager = WindowManager(system: system)
        system.partiallyFailNextWrite = true
        assertError(.operationFailed) { try manager.execute(.leftHalf) }
        try manager.execute(.restore)
        XCTAssertEqual(system.frame, original)
    }

    func testUnchangedFailedWriteDoesNotCreateRestoreEntry() {
        let system = FakeWindowSystem()
        let manager = WindowManager(system: system)
        system.failNextWrite = true
        assertError(.operationFailed) { try manager.execute(.leftHalf) }
        assertError(.noRestoreFrame) { try manager.execute(.restore) }
    }

    func testRestorePreservesOriginalFrameSpanningConnectedDisplays() throws {
        let system = FakeWindowSystem()
        system.displays.append(WindowDisplay(id: 2, frame: CGRect(x: 1440, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 1440, y: 24, width: 1440, height: 850)))
        let spanning = CGRect(x: 1100, y: 100, width: 600, height: 500)
        system.frame = spanning
        let manager = WindowManager(system: system)
        try manager.execute(.leftHalf)
        try manager.execute(.restore)
        XCTAssertEqual(system.frame, spanning)
    }

    func testCenterAndRestorePreserveOversizedFixedSizeWindow() throws {
        let system = FakeWindowSystem()
        let oversized = CGRect(x: -150, y: 5, width: 1700, height: 1000)
        system.frame = oversized
        system.canResize = false
        let manager = WindowManager(system: system)
        try manager.execute(.center)
        XCTAssertEqual(system.frame.size, oversized.size)
        try manager.execute(.restore)
        XCTAssertEqual(system.frame, oversized)
    }

    func testMenuActivationRetainsExactWindowAndNeverFallsBackWhenItCloses() throws {
        let system = FakeWindowSystem()
        let manager = WindowManager(system: system)
        let intended = system.window
        system.activate(system.ownApplication)
        system.window = FakeWindowReference(id: 2, processIdentifier: system.externalApplication.processIdentifier)
        try manager.execute(.leftHalf)
        XCTAssertTrue(system.lastWrittenWindow === intended)
        system.invalidWindowIDs.insert(intended.id)
        assertError(.noWindow) { try manager.execute(.rightHalf) }
        XCTAssertEqual(system.writeCount, 1)
    }

    func testFocusChangesWithinExternalAppUpdateTheRememberedWindow() throws {
        let system = FakeWindowSystem()
        let manager = WindowManager(system: system)
        let next = FakeWindowReference(id: 2, processIdentifier: system.externalApplication.processIdentifier)
        system.window = next
        system.focusChanged?()
        system.activate(system.ownApplication)
        try manager.execute(.leftHalf)
        XCTAssertTrue(system.lastWrittenWindow === next)
    }

    func testTerminatedExternalAppCannotTargetReusedProcess() {
        let system = FakeWindowSystem()
        let manager = WindowManager(system: system)
        system.activate(system.ownApplication)
        system.externalIsAlive = false
        assertError(.noWindow) { try manager.execute(.leftHalf) }
        XCTAssertEqual(system.writeCount, 0)
    }

    func testUnavailableFocusedWindowNeverUsesEarlierWindowInSameExternalApp() {
        let system = FakeWindowSystem()
        let manager = WindowManager(system: system)
        system.focusedWindowUnavailable = true
        assertError(.noWindow) { try manager.execute(.leftHalf) }
        XCTAssertEqual(system.writeCount, 0)
    }

    func testUnsupportedWindowIsRejectedBeforeMutation() {
        for state in [WindowState(frame: original, isMinimized: true, isFullScreen: false, canMove: true, canResize: true),
                      WindowState(frame: original, isMinimized: false, isFullScreen: true, canMove: true, canResize: true),
                      WindowState(frame: original, isMinimized: false, isFullScreen: false, canMove: true, canResize: false)] {
            let system = FakeWindowSystem()
            system.stateOverride = state
            let manager = WindowManager(system: system)
            assertError(.unsupportedWindow) { try manager.execute(.leftHalf) }
            XCTAssertEqual(system.writeCount, 0)
        }
    }

    func testRestoreIsPerActualWindowAndStopReleasesObservation() throws {
        let system = FakeWindowSystem()
        let manager = WindowManager(system: system)
        try manager.execute(.leftHalf)
        system.window = FakeWindowReference(id: 2, processIdentifier: system.externalApplication.processIdentifier)
        assertError(.noRestoreFrame) { try manager.execute(.restore) }
        manager.stop()
        XCTAssertTrue(system.stopped)
        assertError(.noWindow) { try manager.execute(.leftHalf) }
    }

    func testSuccessfulDiagnosticReportsRequestedAndObservedFrameForTargetPID() throws {
        let system = FakeWindowSystem()
        var records: [WindowManagementDiagnostic] = []
        let manager = WindowManager(system: system, diagnostics: { records.append($0) })
        try manager.execute(.leftHalf)
        XCTAssertEqual(records.map(\.stage), ["begin", "target", "frameInitial", "frameRequested", "frameObserved", "success"])
        XCTAssertEqual(records.first(where: { $0.stage == "frameInitial" })?.fields["initialWidth"], "640.0")
        XCTAssertEqual(records.first(where: { $0.stage == "frameRequested" })?.fields["requestedWidth"], "720.0")
        XCTAssertEqual(records.first(where: { $0.stage == "frameObserved" })?.fields["actualWidth"], "720.0")
        XCTAssertEqual(records.last?.fields["targetPID"], "200")
        XCTAssertEqual(records.last?.fields["command"], "leftHalf")
    }

    func testSilentFrameRejectionReportsMismatchInsteadOfSuccessfulWrite() {
        let system = FakeWindowSystem()
        system.ignoreWrites = true
        var records: [WindowManagementDiagnostic] = []
        let manager = WindowManager(system: system, diagnostics: { records.append($0) })
        assertError(.operationFailed) { try manager.execute(.leftHalf) }
        let mismatch = records.first(where: { $0.stage == "mismatch" })
        XCTAssertEqual(mismatch?.fields["requestedWidth"], "720.0")
        XCTAssertEqual(mismatch?.fields["actualWidth"], "640.0")
        XCTAssertFalse(records.contains(where: { $0.stage == "success" }))
        XCTAssertEqual(records.last?.stage, "failure")
        XCTAssertEqual(records.last?.fields["error"], "operationFailed")
    }

    func testThrownNativeBoundaryFailureDoesNotMisreportFrameMismatch() {
        let system = FakeWindowSystem()
        system.failNextWrite = true
        var records: [WindowManagementDiagnostic] = []
        let manager = WindowManager(system: system, diagnostics: { records.append($0) })
        assertError(.operationFailed) { try manager.execute(.leftHalf) }
        XCTAssertFalse(records.contains(where: { $0.stage == "mismatch" || $0.stage == "success" }))
        XCTAssertEqual(records.first(where: { $0.stage == "frameAfterFailure" })?.fields["actualWidth"], "640.0")
        XCTAssertEqual(records.last?.fields["error"], "operationFailed")
        let allowedKeys: Set<String> = ["command", "frontmostPID", "targetPID", "error",
                                       "initialX", "initialY", "initialWidth", "initialHeight",
                                       "requestedX", "requestedY", "requestedWidth", "requestedHeight",
                                       "actualX", "actualY", "actualWidth", "actualHeight"]
        XCTAssertTrue(records.allSatisfy { Set($0.fields.keys).isSubset(of: allowedKeys) })
    }

    func testCalendarMinimumWidthIsAlignedInsideScreenAndOriginalCanBeRestored() throws {
        let system = FakeWindowSystem()
        system.displays = [WindowDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1352, height: 878),
            visibleFrame: CGRect(x: 0, y: 30, width: 1352, height: 848))]
        system.minimumSize = CGSize(width: 918, height: 400)
        system.frame = CGRect(x: 100, y: 80, width: 1000, height: 700)
        let initial = system.frame
        let manager = WindowManager(system: system)
        try manager.execute(.rightHalf)
        XCTAssertEqual(system.frame, CGRect(x: 434, y: 30, width: 918, height: 848))
        try manager.execute(.leftHalf)
        XCTAssertEqual(system.frame, CGRect(x: 0, y: 30, width: 918, height: 848))
        try manager.execute(.restore)
        XCTAssertEqual(system.frame, initial)
    }

    func testQuarterHonorsBothMinimumDimensionsAndRequestedCorner() throws {
        let system = FakeWindowSystem()
        system.minimumSize = CGSize(width: 918, height: 600)
        let manager = WindowManager(system: system)
        try manager.execute(.bottomRight)
        XCTAssertEqual(system.frame, CGRect(x: 522, y: 274, width: 918, height: 600))
    }

    func testCenterThirdCentersMinimumWidthOnOffsetDisplay() throws {
        let system = FakeWindowSystem()
        system.displays = [WindowDisplay(id: 1, frame: CGRect(x: -1440, y: -900, width: 1440, height: 900),
            visibleFrame: CGRect(x: -1440, y: -876, width: 1440, height: 850))]
        system.frame = CGRect(x: -1400, y: -800, width: 1000, height: 700)
        system.minimumSize = CGSize(width: 918, height: 400)
        let manager = WindowManager(system: system)
        try manager.execute(.centerThird)
        XCTAssertEqual(system.frame, CGRect(x: -1179, y: -876, width: 918, height: 850))
    }

    func testIntermediateAnimationFrameIsNotMisclassifiedAsMinimumSize() {
        let system = FakeWindowSystem()
        system.writeTransform = { _ in CGRect(x: 0, y: 401, width: 916, height: 444) }
        let manager = WindowManager(system: system)
        assertError(.operationFailed) { try manager.execute(.leftHalf) }
        XCTAssertEqual(system.writeCount, 1)
    }

    func testUnchangedLargerFrameDoesNotTurnSilentRejectionIntoConstraintSuccess() {
        let system = FakeWindowSystem()
        system.frame = CGRect(x: 0, y: 24, width: 1000, height: 850)
        system.ignoreWrites = true
        let manager = WindowManager(system: system)
        assertError(.operationFailed) { try manager.execute(.leftHalf) }
    }

    func testRepeatingVerifiedConstrainedPlacementRemainsUsable() throws {
        let system = FakeWindowSystem()
        system.minimumSize = CGSize(width: 918, height: 400)
        let manager = WindowManager(system: system)
        let first = try manager.execute(.leftHalf)
        let repeated = try manager.execute(.leftHalf)
        XCTAssertEqual(first, .sizeConstrained(frame: CGRect(x: 0, y: 24, width: 918, height: 850)))
        XCTAssertEqual(repeated, first)
    }

    func testConstrainedPlacementStillRequiresPositionWriteToSucceed() {
        let system = FakeWindowSystem()
        system.minimumSize = CGSize(width: 918, height: 400)
        // The initial resize works, but the app ignores the alignment correction.
        system.writeTransform = { frame in CGRect(x: 720, y: frame.minY, width: frame.width, height: frame.height) }
        let manager = WindowManager(system: system)
        assertError(.operationFailed) { try manager.execute(.rightHalf) }
    }

    private func assertError(_ expected: WindowManagementError, _ operation: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { error in
            XCTAssertEqual(error as? WindowManagementError, expected, file: file, line: line)
        }
    }
}

@MainActor
private final class FakeWindowReference: WindowReference {
    let id: Int
    let processIdentifier: Int32
    init(id: Int, processIdentifier: Int32) { self.id = id; self.processIdentifier = processIdentifier }
    func isSameWindow(as other: any WindowReference) -> Bool { (other as? FakeWindowReference)?.id == id && other.processIdentifier == processIdentifier }
}

@MainActor
private final class FakeWindowSystem: WindowSystem {
    let ownProcessIdentifier: Int32 = 100
    let ownApplication = WindowApplication(processIdentifier: 100, launchDate: Date(timeIntervalSince1970: 1))
    let externalApplication = WindowApplication(processIdentifier: 200, launchDate: Date(timeIntervalSince1970: 2))
    var hasAccessibilityAccess = true
    var requestCount = 0
    var currentApplication: WindowApplication?
    var externalIsAlive = true
    var window = FakeWindowReference(id: 1, processIdentifier: 200)
    var frame = CGRect(x: 120, y: 100, width: 640, height: 500)
    var stateOverride: WindowState?
    var canResize = true
    var minimumSize: CGSize?
    var writeTransform: ((CGRect) -> CGRect)?
    var invalidWindowIDs: Set<Int> = []
    var lastWrittenWindow: FakeWindowReference?
    var writeCount = 0
    var failNextWrite = false
    var ignoreWrites = false
    var focusedWindowUnavailable = false
    var partiallyFailNextWrite = false
    var stopped = false
    var activationChanged: (@MainActor (WindowApplication) -> Void)?
    var focusChanged: (@MainActor () -> Void)?
    var displays = [WindowDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 24, width: 1440, height: 850))]

    init() { currentApplication = externalApplication }
    func requestAccessibilityAccess() -> Bool { requestCount += 1; return hasAccessibilityAccess }
    func isAlive(_ application: WindowApplication) -> Bool { externalIsAlive && application == externalApplication }
    func focusedWindow(in application: WindowApplication) throws -> any WindowReference {
        if focusedWindowUnavailable { throw WindowManagementError.noWindow }
        return window
    }
    func state(of window: any WindowReference) throws -> WindowState {
        if let reference = window as? FakeWindowReference, invalidWindowIDs.contains(reference.id) { throw WindowManagementError.noWindow }
        return stateOverride ?? WindowState(frame: frame, isMinimized: false, isFullScreen: false, canMove: true, canResize: canResize)
    }
    func setFrame(_ frame: CGRect, of window: any WindowReference) throws {
        writeCount += 1
        lastWrittenWindow = window as? FakeWindowReference
        if failNextWrite { failNextWrite = false; throw WindowManagementError.operationFailed }
        if ignoreWrites { return }
        var accepted = frame
        if let minimumSize {
            accepted.size = CGSize(width: max(frame.width, minimumSize.width), height: max(frame.height, minimumSize.height))
        }
        self.frame = writeTransform?(accepted) ?? accepted
        if partiallyFailNextWrite { partiallyFailNextWrite = false; throw WindowManagementError.operationFailed }
    }
    func observeApplications(_ callback: @escaping @MainActor (WindowApplication) -> Void) { activationChanged = callback }
    func observeFocusedWindow(in application: WindowApplication, callback: @escaping @MainActor () -> Void) { focusChanged = callback }
    func stopObserving() { stopped = true; activationChanged = nil; focusChanged = nil }
    func activate(_ app: WindowApplication) { currentApplication = app; activationChanged?(app) }
}

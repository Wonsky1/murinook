import XCTest
@testable import MurinookWindowManagement

@MainActor
final class AccessibilityFrameAdjustmentTests: XCTestCase {
    func testEnabledEnhancedUIIsDisabledForWriteAndRestoredAfterwards() throws {
        var enabled = true
        var writes: [Bool] = []
        try AccessibilityFrameAdjustment.perform(readEnhancedUI: { enabled }, writeEnhancedUI: {
            enabled = $0; writes.append($0); return true
        }) {
            XCTAssertFalse(enabled, "Frame writes must bypass enhanced-UI animation")
        }
        XCTAssertEqual(writes, [false, true])
        XCTAssertTrue(enabled)
    }

    func testEnhancedUIIsRestoredEvenWhenFrameWriteThrows() {
        var enabled = true
        XCTAssertThrowsError(try AccessibilityFrameAdjustment.perform(readEnhancedUI: { enabled }, writeEnhancedUI: {
            enabled = $0; return true
        }) {
            XCTAssertFalse(enabled)
            throw WindowManagementError.operationFailed
        })
        XCTAssertTrue(enabled)
    }

    func testUnsupportedOrDisabledEnhancedUIIsNotChanged() throws {
        for value: Bool? in [false, nil] {
            var writes: [Bool] = []
            var adjusted = false
            try AccessibilityFrameAdjustment.perform(readEnhancedUI: { value }, writeEnhancedUI: {
                writes.append($0); return true
            }) { adjusted = true }
            XCTAssertTrue(writes.isEmpty)
            XCTAssertTrue(adjusted)
        }
    }

    func testRejectedGuardDoesNotBlockFrameWriteOrEnableUnknownState() throws {
        var writes: [Bool] = []
        var adjusted = false
        try AccessibilityFrameAdjustment.perform(readEnhancedUI: { true }, writeEnhancedUI: {
            writes.append($0); return false
        }) { adjusted = true }
        XCTAssertEqual(writes, [false])
        XCTAssertTrue(adjusted)
    }
}

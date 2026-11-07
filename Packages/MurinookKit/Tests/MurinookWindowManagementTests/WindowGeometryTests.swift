import CoreGraphics
import MurinookDomain
import XCTest
@testable import MurinookWindowManagement

final class WindowGeometryTests: XCTestCase {
    func testAppKitConversionUsesPrimaryScreenTopAndPreservesNegativeOffsets() {
        let appKit = CGRect(x: -1600, y: 300, width: 1600, height: 900)
        let converted = WindowGeometry.accessibilityFrame(fromAppKit: appKit, primaryScreenTop: 1080)
        XCTAssertEqual(converted, CGRect(x: -1600, y: -120, width: 1600, height: 900))
    }

    func testLayoutsRespectVisibleFrameInsteadOfDisplayBounds() throws {
        let visible = CGRect(x: -1440, y: -300, width: 1440, height: 860)
        let original = CGRect(x: -1300, y: 0, width: 600, height: 400)
        XCTAssertEqual(try WindowGeometry.frame(for: .topRight, current: original, visible: visible),
                       CGRect(x: -720, y: -300, width: 720, height: 430))
        XCTAssertEqual(try WindowGeometry.frame(for: .bottomLeft, current: original, visible: visible),
                       CGRect(x: -1440, y: 130, width: 720, height: 430))
        XCTAssertEqual(try WindowGeometry.frame(for: .center, current: original, visible: visible),
                       CGRect(x: -1020, y: -70, width: 600, height: 400))
    }

    func testThirdsShareExactBoundariesForFractionalPointWidths() throws {
        let visible = CGRect(x: 10, y: 24, width: 1000, height: 700)
        let first = try WindowGeometry.frame(for: .firstThird, current: .zero, visible: visible)
        let center = try WindowGeometry.frame(for: .centerThird, current: .zero, visible: visible)
        let last = try WindowGeometry.frame(for: .lastThird, current: .zero, visible: visible)
        XCTAssertEqual(first.maxX, center.minX, accuracy: 0.0001)
        XCTAssertEqual(center.maxX, last.minX, accuracy: 0.0001)
        XCTAssertEqual(last.maxX, visible.maxX, accuracy: 0.0001)
    }

    func testCenterPreservesOversizedWindowDimensions() throws {
        let visible = CGRect(x: 100, y: 24, width: 1000, height: 700)
        let oversized = CGRect(x: -100, y: -100, width: 1500, height: 1000)
        let result = try WindowGeometry.frame(for: .center, current: oversized, visible: visible)
        XCTAssertEqual(result, CGRect(x: 100, y: 24, width: 1500, height: 1000))
    }

    func testDisplaySelectionUsesLargestIntersectionAndStableSpatialOrder() throws {
        let left = WindowDisplay(id: 5, frame: CGRect(x: -1000, y: 0, width: 1000, height: 800), visibleFrame: CGRect(x: -1000, y: 24, width: 1000, height: 776))
        let right = WindowDisplay(id: 3, frame: CGRect(x: 0, y: 0, width: 1500, height: 900), visibleFrame: CGRect(x: 0, y: 24, width: 1500, height: 876))
        XCTAssertEqual(try WindowGeometry.display(for: CGRect(x: -100, y: 30, width: 500, height: 400), among: [left, right]).id, right.id)
        XCTAssertEqual(try WindowGeometry.adjacentDisplay(to: right, among: [right, left], forward: true).id, left.id)
        XCTAssertThrowsError(try WindowGeometry.adjacentDisplay(to: left, among: [left], forward: true))
    }

    func testTransferPreservesProportionsAndClampsOversizedFrames() {
        let source = CGRect(x: -1000, y: 24, width: 1000, height: 800)
        let target = CGRect(x: 0, y: -900, width: 1600, height: 900)
        let original = CGRect(x: -750, y: 224, width: 500, height: 400)
        XCTAssertEqual(WindowGeometry.transferred(original, from: source, to: target),
                       CGRect(x: 400, y: -675, width: 800, height: 450))
        XCTAssertEqual(WindowGeometry.clamped(CGRect(x: -4000, y: 5000, width: 3000, height: 2000), to: source), source)
    }
}

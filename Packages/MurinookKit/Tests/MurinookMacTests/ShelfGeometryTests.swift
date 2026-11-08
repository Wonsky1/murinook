import CoreGraphics
import XCTest
import MurinookDomain
@testable import MurinookMacIntegration

final class ShelfGeometryTests: XCTestCase {
    func testOriginUsesNormalizedTwoDimensionalPlacement() {
        let bounds = CGRect(x: -1_000, y: -200, width: 1_000, height: 800)
        let panel = CGSize(width: 200, height: 300)

        XCTAssertEqual(
            ShelfGeometry.origin(in: bounds, panelSize: panel, position: ShelfPosition(x: 0, y: 0)),
            CGPoint(x: -1_000, y: -200)
        )
        XCTAssertEqual(
            ShelfGeometry.origin(in: bounds, panelSize: panel, position: ShelfPosition(x: 1, y: 1)),
            CGPoint(x: -200, y: 300)
        )
        XCTAssertEqual(
            ShelfGeometry.origin(in: bounds, panelSize: panel, position: ShelfPosition(x: 0.25, y: 0.5)),
            CGPoint(x: -800, y: 50)
        )
    }

    func testPositionRoundTripsAndAdaptsToResizedDisplay() {
        let firstBounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        let panel = CGSize(width: 200, height: 300)
        let firstOrigin = CGPoint(x: 320, y: 125)
        let position = ShelfGeometry.normalizedPosition(forOrigin: firstOrigin, in: firstBounds, panelSize: panel)

        XCTAssertEqual(position, ShelfPosition(x: 0.4, y: 0.25))
        XCTAssertEqual(
            ShelfGeometry.origin(in: CGRect(x: 0, y: 0, width: 1_600, height: 1_000), panelSize: panel, position: position),
            CGPoint(x: 560, y: 175)
        )
    }

    func testGeometryClampsToNegativeBoundsAndOversizedPanel() {
        let bounds = CGRect(x: -400, y: -100, width: 300, height: 200)
        XCTAssertEqual(
            ShelfGeometry.origin(in: bounds, panelSize: CGSize(width: 500, height: 300), position: ShelfPosition(x: 1, y: 1)),
            CGPoint(x: -400, y: -100)
        )
        XCTAssertEqual(
            ShelfGeometry.normalizedPosition(forOrigin: CGPoint(x: -900, y: 900), in: bounds, panelSize: CGSize(width: 100, height: 50)),
            ShelfPosition(x: 0, y: 1)
        )
    }

    func testOriginSanitizesPositionMutatedAfterInitialization() {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        var position = ShelfPosition(x: 0.2, y: 0.2)
        position.x = 4
        position.y = .nan

        XCTAssertEqual(
            ShelfGeometry.origin(in: bounds, panelSize: CGSize(width: 200, height: 300), position: position),
            CGPoint(x: 800, y: 250)
        )
    }
}

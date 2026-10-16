import CoreGraphics
import XCTest
@testable import MurinookMacIntegration

final class ShelfEdgeGeometryTests: XCTestCase {
    func testOriginAnchorsPanelToRequestedEdgeAndOffset() {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        let panel = CGSize(width: 200, height: 300)

        XCTAssertEqual(
            ShelfEdgeGeometry.origin(in: bounds, panelSize: panel, side: .left, normalizedOffset: 0.5),
            CGPoint(x: 0, y: 250)
        )
        XCTAssertEqual(
            ShelfEdgeGeometry.origin(in: bounds, panelSize: panel, side: .right, normalizedOffset: 1),
            CGPoint(x: 800, y: 500)
        )
    }

    func testOffsetClampsAndRoundTripsFromReleasedOrigin() {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        let panel = CGSize(width: 200, height: 300)

        XCTAssertEqual(ShelfEdgeGeometry.normalizedOffset(forOrigin: CGPoint(x: -40, y: -100), in: bounds, panelSize: panel), 0)
        XCTAssertEqual(ShelfEdgeGeometry.normalizedOffset(forOrigin: CGPoint(x: 900, y: 900), in: bounds, panelSize: panel), 1)
        XCTAssertEqual(ShelfEdgeGeometry.normalizedOffset(forOrigin: CGPoint(x: 0, y: 375), in: bounds, panelSize: panel), 0.75)
    }

    func testOversizedPanelAndInvalidOffsetStayInsideUsableBounds() {
        let bounds = CGRect(x: 20, y: 30, width: 400, height: 300)
        let origin = ShelfEdgeGeometry.origin(
            in: bounds,
            panelSize: CGSize(width: 500, height: 400),
            side: .right,
            normalizedOffset: .nan
        )
        XCTAssertEqual(origin, CGPoint(x: 20, y: 30))
    }
}

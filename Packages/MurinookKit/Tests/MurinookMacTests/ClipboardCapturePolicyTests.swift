import AppKit
import XCTest
@testable import MurinookMacIntegration

final class ClipboardCapturePolicyTests: XCTestCase {
    func testConcealedOrTransientMarkerOnAnyItemRejectsWholeGeneration() {
        let policy = ClipboardCapturePolicy()
        let ordinaryItem = NSPasteboardItem()
        ordinaryItem.setString("ordinary", forType: .string)
        for marker in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"] {
            let markedItem = NSPasteboardItem()
            markedItem.setString("sensitive", forType: .string)
            markedItem.setData(Data(), forType: NSPasteboard.PasteboardType(marker))

            XCTAssertTrue(policy.rejectsEntireGeneration(containing: [ordinaryItem, markedItem]), marker)
            XCTAssertFalse(policy.rejectsEntireGeneration(containing: [ordinaryItem]))
        }
    }
}

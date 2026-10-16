import AppKit
import XCTest
@testable import MurinookMacIntegration

@MainActor
final class ClipboardWriterTests: XCTestCase {
    func testWriterPreservesMultipleItemsAndRepresentationsOnPrivatePasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MurinookTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let registry = ClipboardWriteRegistry()
        let writer = ClipboardContentWriter(pasteboard: pasteboard, writeRegistry: registry)
        let items = [
            ClipboardItemSnapshot(representations: [
                ClipboardRepresentationSnapshot(typeIdentifier: "public.utf8-plain-text", data: Data("hello".utf8)),
                ClipboardRepresentationSnapshot(typeIdentifier: "com.example.rich", data: Data([0, 1, 2, 255]))
            ]),
            ClipboardItemSnapshot(representations: [
                ClipboardRepresentationSnapshot(typeIdentifier: "com.example.second", data: Data([9, 8]))
            ])
        ]

        let token = try writer.write(items)
        XCTAssertEqual(token.changeCount, pasteboard.changeCount)
        XCTAssertTrue(registry.consume(token.changeCount))
        XCTAssertFalse(registry.consume(token.changeCount))
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 2)
        XCTAssertEqual(pasteboard.pasteboardItems?[0].data(forType: .init("public.utf8-plain-text")), Data("hello".utf8))
        XCTAssertEqual(pasteboard.pasteboardItems?[0].data(forType: .init("com.example.rich")), Data([0, 1, 2, 255]))
        XCTAssertEqual(pasteboard.pasteboardItems?[1].data(forType: .init("com.example.second")), Data([9, 8]))
    }
}

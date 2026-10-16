import AppKit
import XCTest
import MurinookDomain
@testable import MurinookMacIntegration

final class ClipContentBridgeTests: XCTestCase {
    func testFileRepresentationsDoNotDuplicateFileReferencesDuringClipboardReconstruction() throws {
        let first = FileReference(url: URL(fileURLWithPath: "/tmp/one.txt"))
        let second = FileReference(url: URL(fileURLWithPath: "/tmp/two.pdf"))
        let content = ClipContent(
            representations: [
                ClipRepresentation(typeIdentifier: "public.file-url", data: Data(first.url.absoluteString.utf8)),
                ClipRepresentation(typeIdentifier: "com.example.preview", data: Data([1, 2, 3]))
            ],
            files: [first, second]
        )

        let items = content.clipboardItems

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].representations.map(\.typeIdentifier), ["com.example.preview"])
        XCTAssertEqual(items[1].files, [first])
        XCTAssertEqual(items[2].files, [second])
        XCTAssertEqual(items[1].representations.first?.typeIdentifier, "public.file-url")
        XCTAssertEqual(items[2].representations.first?.typeIdentifier, "public.file-url")
    }
}

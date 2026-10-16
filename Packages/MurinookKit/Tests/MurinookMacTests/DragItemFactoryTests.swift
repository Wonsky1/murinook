import AppKit
import XCTest
import MurinookDomain
@testable import MurinookMacIntegration

@MainActor
final class DragItemFactoryTests: XCTestCase {
    func testFactoryPreservesRichItemAndSeparatesMultipleFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookDragTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstURL = directory.appendingPathComponent("first.txt")
        let secondURL = directory.appendingPathComponent("second.pdf")
        try Data("first".utf8).write(to: firstURL)
        try Data("second".utf8).write(to: secondURL)
        let richData = Data([0, 2, 255, 7])
        let content = ClipContent(
            representations: [ClipRepresentation(typeIdentifier: "com.example.rich", data: richData)],
            files: [FileReference(url: firstURL), FileReference(url: secondURL)]
        )

        let draggingItems = try DragItemFactory(bookmarks: BookmarkAdapter()).makeItems(for: content)

        XCTAssertEqual(draggingItems.count, 3)
        let richWriter = try XCTUnwrap(draggingItems[0].item as? NSPasteboardItem)
        XCTAssertEqual(richWriter.data(forType: NSPasteboard.PasteboardType("com.example.rich")), richData)
        for (index, expectedURL) in [(1, firstURL), (2, secondURL)] {
            let writer = try XCTUnwrap(draggingItems[index].item as? NSURL)
            XCTAssertEqual(writer as URL, expectedURL)
            XCTAssertGreaterThan(draggingItems[index].draggingFrame.width, 0)
            XCTAssertGreaterThan(draggingItems[index].draggingFrame.height, 0)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path))
    }
}

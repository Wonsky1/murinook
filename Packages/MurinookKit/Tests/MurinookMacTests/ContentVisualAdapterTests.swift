import AppKit
import MurinookDomain
import XCTest
@testable import MurinookMacIntegration

@MainActor
final class ContentVisualAdapterTests: XCTestCase {
    func testFileVisualDoesNotCopyOriginalAndSurvivesSerialization() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookVisuals-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("opaque.unknown-extension")
        try Data([1, 255, 3]).write(to: original)
        let bookmarks = BookmarkAdapter()
        let content = ClipContent(files: [.init(url: original, bookmark: try bookmarks.createBookmark(for: original))])
        let result = await ContentVisualAdapter(bookmarks: bookmarks).addingVisuals(to: content)
        XCTAssertEqual(result.files.first?.url, original)
        XCTAssertFalse(try XCTUnwrap(result.files.first).isOwnedCopy)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [original.lastPathComponent])
        let icon = try XCTUnwrap(result.iconData)
        let image = try XCTUnwrap(NSBitmapImageRep(data: icon))
        XCTAssertLessThanOrEqual(image.pixelsWide, 96)
        XCTAssertLessThanOrEqual(image.pixelsHigh, 96)
        XCTAssertEqual(result.fingerprint, content.fingerprint)
        let restored = try JSONDecoder().decode(ClipContent.self, from: JSONEncoder().encode(result))
        XCTAssertEqual(restored.iconData, icon)
        XCTAssertEqual(restored.files.first?.iconData, icon)
    }

    func testClipboardImageGetsBoundedThumbnail() async throws {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 400, pixelsHigh: 200,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let bytes = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let original = ClipContent(representations: [.init(typeIdentifier: "public.png", data: bytes)])
        let result = await ContentVisualAdapter(bookmarks: BookmarkAdapter()).addingVisuals(to: original)
        let image = try XCTUnwrap(result.iconData.flatMap(NSBitmapImageRep.init(data:)))
        XCTAssertEqual(image.pixelsWide, 96)
        XCTAssertEqual(image.pixelsHigh, 48)
        XCTAssertEqual(result.representations, original.representations)
        XCTAssertEqual(result.fingerprint, original.fingerprint)
    }
}

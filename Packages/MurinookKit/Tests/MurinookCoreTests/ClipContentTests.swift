import XCTest
import MurinookDomain

final class ClipContentTests: XCTestCase {
    func testCommonImageTypeIdentifiersClassifyAsImage() {
        let identifiers = ["public.heic", "public.tiff", "public.gif", "org.webmproject.webp", "public.svg-image"]
        for identifier in identifiers {
            let content = ClipContent(representations: [.init(typeIdentifier: identifier, data: Data([1]))])
            XCTAssertEqual(content.kind, .image, "Expected \(identifier) to classify as an image")
        }
    }

    func testByteCountUsesActualFileSizesAndRepresentationBytes() {
        let content = ClipContent(
            representations: [.init(typeIdentifier: "public.utf8-plain-text", data: Data([1, 2, 3]))],
            files: [
                .init(url: URL(fileURLWithPath: "/tmp/a"), byteCount: 17),
                .init(url: URL(fileURLWithPath: "/tmp/b"), byteCount: 23),
                .init(url: URL(fileURLWithPath: "/tmp/c"))
            ]
        )
        XCTAssertEqual(content.byteCount, 43)
    }

    func testOlderFileReferenceEncodingDefaultsMissingByteCountToNil() throws {
        let oldPayload = Data(#"{"url":"file:///tmp/old.txt","bookmark":null,"isOwnedCopy":false}"#.utf8)
        let decoded = try JSONDecoder().decode(FileReference.self, from: oldPayload)
        XCTAssertNil(decoded.byteCount)
    }

    func testOlderClipEncodingDefaultsMissingSearchTextToNil() throws {
        let oldPayload = Data(#"{"id":"00000000-0000-0000-0000-000000000001","contentID":"00000000-0000-0000-0000-000000000002","title":"Old clip","preview":"short preview","kind":"text","source":{"name":"Notes"},"createdAt":0,"lastCopiedAt":0,"isPinned":false,"collectionIDs":[],"tags":[],"note":"","byteCount":0,"fingerprint":"old"}"#.utf8)
        let decoded = try JSONDecoder().decode(Clip.self, from: oldPayload)
        XCTAssertNil(decoded.searchText)
        XCTAssertEqual(decoded.preview, "short preview")
    }
}

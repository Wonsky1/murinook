import AppKit
import XCTest
@testable import MurinookMacIntegration

@MainActor
final class FileImportAdapterTests: XCTestCase {
    func testOwnedImportCopiesPayloadAndNeverDeletesExternalOriginal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookImportTests-\(UUID().uuidString)", isDirectory: true)
        let sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
        let ownedDirectory = root.appendingPathComponent("owned", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = sourceDirectory.appendingPathComponent("payload.txt")
        let contents = Data("external payload".utf8)
        try contents.write(to: source)

        let adapter = try FileImportAdapter(bookmarks: BookmarkAdapter(), ownedFilesDirectory: ownedDirectory)
        let imported = try adapter.makeOwnedCopy(of: source)

        XCTAssertTrue(imported.isOwnedCopy)
        XCTAssertNotEqual(imported.url, source)
        XCTAssertEqual(try Data(contentsOf: imported.url), contents)
        XCTAssertEqual(try Data(contentsOf: source), contents)
    }
    func testFileURLDataProviderRetainsOriginalReferenceWithoutCopying() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookURLImport-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("example.unknown-extension")
        let bytes = Data([0, 255, 3, 10, 128])
        try bytes.write(to: source)
        let provider = NSItemProvider()
        let urlData = Data(source.absoluteString.utf8)
        provider.registerDataRepresentation(forTypeIdentifier: "public.file-url", visibility: .all) { completion in
            completion(urlData, nil)
            return nil
        }
        let adapter = try FileImportAdapter(bookmarks: BookmarkAdapter(), ownedFilesDirectory: root.appendingPathComponent("owned"))
        let imported = try await adapter.importProviders([provider])
        XCTAssertEqual(imported.count, 1)
        let file = try XCTUnwrap(imported.first?.files.first)
        XCTAssertFalse(file.isOwnedCopy)
        XCTAssertEqual(file.url, source)
        let bookmark = try XCTUnwrap(file.bookmark)
        XCTAssertEqual(try BookmarkAdapter().resolve(bookmark).resolvingSymlinksInPath(), source.resolvingSymlinksInPath())
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("owned").path), [])
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }

    func testFolderProviderPreservesContentsAndSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookFolderImport-\(UUID())")
        let source = root.appendingPathComponent("my folder", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = source.appendingPathComponent("nested.opaque")
        try Data("folder payload".utf8).write(to: nested)
        let provider = NSItemProvider(contentsOf: source) ?? NSItemProvider(object: source as NSURL)
        let adapter = try FileImportAdapter(bookmarks: BookmarkAdapter(), ownedFilesDirectory: root.appendingPathComponent("owned"))
        let contents = try await adapter.importProviders([provider])
        let file = try XCTUnwrap(contents.first?.files.first)
        XCTAssertFalse(file.isOwnedCopy)
        XCTAssertEqual(file.url, source)
        XCTAssertNotNil(file.bookmark)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("owned").path), [])
        XCTAssertEqual(try Data(contentsOf: file.url.appendingPathComponent("nested.opaque")), try Data(contentsOf: nested))
    }

    func testOwnedFileReimportPreservesCustodyWithoutAnotherCopy() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookOwnedReference-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.docx")
        try Data([80, 75, 3, 4]).write(to: source)
        let ownedDirectory = root.appendingPathComponent("owned")
        let adapter = try FileImportAdapter(bookmarks: BookmarkAdapter(), ownedFilesDirectory: ownedDirectory)
        let owned = try adapter.makeOwnedCopy(of: source)
        let provider = NSItemProvider()
        let data = Data(owned.url.absoluteString.utf8)
        provider.registerDataRepresentation(forTypeIdentifier: "public.file-url", visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        let imported = try await adapter.importProviders([provider])
        let file = try XCTUnwrap(imported.first?.files.first)
        XCTAssertTrue(file.isOwnedCopy)
        XCTAssertEqual(file.url, owned.url)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: ownedDirectory.path).count, 1)
    }

    func testInPlaceDocxProviderRetainsOriginalWithoutMaterializing() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookInPlace-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("document.docx")
        try Data([80, 75, 3, 4]).write(to: source)
        let provider = NSItemProvider()
        provider.registerFileRepresentation(forTypeIdentifier: "org.openxmlformats.wordprocessingml.document", fileOptions: .openInPlace, visibility: .all) { completion in
            completion(source, true, nil)
            return nil
        }
        let adapter = try FileImportAdapter(bookmarks: BookmarkAdapter(), ownedFilesDirectory: root.appendingPathComponent("owned"))
        let imported = try await adapter.importProviders([provider])
        let file = try XCTUnwrap(imported.first?.files.first)
        XCTAssertFalse(file.isOwnedCopy)
        XCTAssertEqual(file.url.resolvingSymlinksInPath(), source.resolvingSymlinksInPath())
        XCTAssertNotNil(file.bookmark)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("owned").path), [])
    }

    func testDocxFileRepresentationImportsAsAFileWithoutFileURLType() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookDocxImport-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("document.docx")
        let bytes = Data([80, 75, 3, 4, 128, 255])
        try bytes.write(to: source)
        let provider = NSItemProvider()
        provider.registerFileRepresentation(forTypeIdentifier: "org.openxmlformats.wordprocessingml.document", fileOptions: [], visibility: .all) { completion in
            completion(source, false, nil)
            return nil
        }
        let adapter = try FileImportAdapter(bookmarks: BookmarkAdapter(), ownedFilesDirectory: root.appendingPathComponent("owned"))
        let imported = try await adapter.importProviders([provider])
        XCTAssertEqual(imported.count, 1)
        let file = try XCTUnwrap(imported.first?.files.first)
        XCTAssertTrue(file.isOwnedCopy)
        XCTAssertEqual(file.url.lastPathComponent, "document.docx")
        XCTAssertEqual(try Data(contentsOf: file.url), bytes)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }

    func testNativeDropCapturesEveryFileAndPreservesDuplicateNames() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookNativeDrop-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let firstDirectory = root.appendingPathComponent("a")
        let secondDirectory = root.appendingPathComponent("b")
        try FileManager.default.createDirectory(at: firstDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondDirectory, withIntermediateDirectories: true)
        let first = firstDirectory.appendingPathComponent("same.docx")
        let second = secondDirectory.appendingPathComponent("same.docx")
        try Data("first".utf8).write(to: first)
        try Data("second".utf8).write(to: second)
        let board = NSPasteboard(name: .init("MurinookDrop-\(UUID())"))
        defer { board.releaseGlobally() }
        XCTAssertTrue(board.writeObjects([first as NSURL, second as NSURL]))
        let adapter = try FileImportAdapter(bookmarks: BookmarkAdapter(), ownedFilesDirectory: root.appendingPathComponent("owned"))
        let captured = try adapter.captureExternalFiles(from: board)
        XCTAssertEqual(captured.count, 2)
        let imported = try await adapter.importExternalFiles(captured)
        let files = imported.flatMap(\.files)
        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files.map { $0.url.lastPathComponent }, ["same.docx", "same.docx"])
        XCTAssertEqual(files.map(\.url), [first, second])
        XCTAssertTrue(files.allSatisfy { !$0.isOwnedCopy && $0.bookmark != nil })
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("owned").path), [])
        XCTAssertEqual(try Data(contentsOf: files[0].url), Data("first".utf8))
        XCTAssertEqual(try Data(contentsOf: files[1].url), Data("second".utf8))
    }

    func testFileRepresentationLargerThanClipboardLimitIsStoredWithoutTruncation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookLargeFile-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("large.custom")
        FileManager.default.createFile(atPath: source.path, contents: nil)
        let handle = try FileHandle(forWritingTo: source)
        let size: UInt64 = 40 * 1_024 * 1_024
        try handle.truncate(atOffset: size)
        try handle.seek(toOffset: size - 4)
        try handle.write(contentsOf: Data([1, 128, 255, 7]))
        try handle.close()
        let provider = NSItemProvider()
        provider.registerFileRepresentation(forTypeIdentifier: "public.data", fileOptions: [], visibility: .all) { completion in
            completion(source, false, nil)
            return nil
        }
        let adapter = try FileImportAdapter(bookmarks: BookmarkAdapter(), ownedFilesDirectory: root.appendingPathComponent("owned"))
        let contents = try await adapter.importProviders([provider])
        let file = try XCTUnwrap(contents.first?.files.first)
        XCTAssertEqual(file.byteCount, Int(size))
        let imported = try FileHandle(forReadingFrom: file.url)
        defer { try? imported.close() }
        try imported.seek(toOffset: size - 4)
        XCTAssertEqual(try imported.read(upToCount: 4), Data([1, 128, 255, 7]))
    }

}

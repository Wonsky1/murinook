import Foundation
import XCTest
@testable import MurinookMacIntegration

@MainActor
final class ExportAdapterTests: XCTestCase {
    func testCopyToSameFileFailsWithoutDeletingOriginal() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("original.txt")
        let bytes = Data("preserve this file".utf8)
        try bytes.write(to: original)

        XCTAssertThrowsError(try ExportAdapter.copyFile(source: original, to: original))
        XCTAssertEqual(try Data(contentsOf: original), bytes)
    }

    func testReplacementPreservesSourceAndReplacesDestinationWithCompleteCopy() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.txt")
        let destination = directory.appendingPathComponent("destination.txt")
        let sourceBytes = Data("complete source payload".utf8)
        try sourceBytes.write(to: source)
        try Data("old destination".utf8).write(to: destination)

        try ExportAdapter.copyFile(source: source, to: destination)

        XCTAssertEqual(try Data(contentsOf: source), sourceBytes)
        XCTAssertEqual(try Data(contentsOf: destination), sourceBytes)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix(".murinook-export-") })
    }

    func testDirectoryContainmentIsRejectedWithoutTouchingOriginal() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let folder = directory.appendingPathComponent("original", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("child.txt")
        let bytes = Data("original child".utf8)
        try bytes.write(to: file)
        XCTAssertThrowsError(try ExportAdapter.copyFile(source: file, to: folder))
        XCTAssertThrowsError(try ExportAdapter.copyFile(source: folder, to: folder.appendingPathComponent("copy")))
        XCTAssertEqual(try Data(contentsOf: file), bytes)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["child.txt"])
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookExportTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

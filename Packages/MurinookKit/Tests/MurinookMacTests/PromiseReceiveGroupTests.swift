import AppKit
import XCTest
@testable import MurinookMacIntegration

@MainActor
final class PromiseReceiveGroupTests: XCTestCase {
    func testDeliveredCallbackIsBufferedUntilBatchValueIsAwaited() async throws {
        let (root, staging, destination) = try makeDirectories()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = staging.appendingPathComponent("example.docx")
        try Data("promise payload".utf8).write(to: source)
        let group = PromiseReceiveGroup(stagingDirectory: staging, destinationDirectory: destination,
            fileManager: .default)

        group.setExpectedCount(1)
        group.record(url: source, error: nil)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))

        let files = try await group.value()
        XCTAssertEqual(files.map(\.displayName), ["example.docx"])
        let file = try XCTUnwrap(files.first)
        XCTAssertEqual(try Data(contentsOf: file.url), Data("promise payload".utf8))
        XCTAssertTrue(file.isOwnedCopy)
    }

    func testAllErrorCallbacksRemoveStagingBeforeAwaitedFailureReturns() async throws {
        let (root, staging, destination) = try makeDirectories()
        defer { try? FileManager.default.removeItem(at: root) }
        let group = PromiseReceiveGroup(stagingDirectory: staging, destinationDirectory: destination,
            fileManager: .default)

        group.setExpectedCount(1)
        group.record(url: nil, error: CocoaError(.fileReadNoSuchFile))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))

        do {
            _ = try await group.value()
            XCTFail("Expected the failed promise callback to fail the receipt")
        } catch {
            XCTAssertTrue(error is FileImportError)
        }
    }

    private func makeDirectories() throws -> (root: URL, staging: URL, destination: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PromiseReceiveGroupTests-\(UUID())", isDirectory: true)
        let staging = root.appendingPathComponent(".promise-stage", isDirectory: true)
        let destination = root.appendingPathComponent("owned", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        return (root, staging, destination)
    }
}

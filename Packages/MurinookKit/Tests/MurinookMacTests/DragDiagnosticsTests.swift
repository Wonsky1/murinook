import Foundation
import XCTest
@testable import MurinookMacIntegration

@MainActor
final class DragDiagnosticsTests: XCTestCase {
    func testTraceRetainsGestureIdentityAndOmitsPathsAndErrorContents() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let trace = DragDiagnostics(directory: directory)
        let first = trace.beginDrag(changeCount: 10)
        XCTAssertEqual(trace.beginDrag(changeCount: 10), first)
        trace.event("file.captured", fields: trace.fileFields(URL(fileURLWithPath: "/private/hidden-parent/example.docx") as NSURL))
        let next = trace.beginDrag(changeCount: 11)
        XCTAssertNotEqual(first, next)
        trace.event("old_drop.finished", fields: trace.errorFields(NSError(domain: NSCocoaErrorDomain, code: 256,
            userInfo: [NSLocalizedDescriptionKey: "secret document contents"])), dragID: first)
        await trace.flush()

        let data = try Data(contentsOf: trace.fileURL)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(text.contains("hidden-parent"))
        XCTAssertFalse(text.contains("secret document contents"))
        let records = try decode(data)
        XCTAssertEqual(records.last?["dragID"] as? String, first)
        XCTAssertEqual(records.last?["event"] as? String, "old_drop.finished")
        XCTAssertEqual(records.compactMap { $0["sequence"] as? Int }, Array(1...records.count))
        XCTAssertEqual(Set(records.compactMap { $0["runID"] as? String }), [trace.runID])
    }

    func testRotationKeepsOnlyTwoBoundedFilesWithCompleteJSONRecords() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let trace = DragDiagnostics(directory: directory, maximumFileBytes: 1_024)
        for index in 0..<30 {
            trace.event("drop.progress", fields: ["index": String(index), "metadata": String(repeating: "x", count: 300)])
        }
        await trace.flush()

        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(Set(files.map(\.lastPathComponent)), ["drag-diagnostics.jsonl", "drag-diagnostics.jsonl.previous"])
        for file in files {
            let data = try Data(contentsOf: file)
            XCTAssertLessThanOrEqual(data.count, 1_024)
            XCTAssertEqual(data.last, 0x0A)
            XCTAssertFalse(try decode(data).isEmpty)
        }
        let records = try decode(Data(contentsOf: trace.fileURL))
        XCTAssertEqual((records.last?["fields"] as? [String: String])?["index"], "29")
    }

    private func decode(_ data: Data) throws -> [[String: Any]] {
        try data.split(separator: 0x0A).map {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data($0)) as? [String: Any])
        }
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("DragDiagnostics-\(UUID())", isDirectory: true)
    }
}

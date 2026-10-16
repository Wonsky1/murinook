import AppKit
import XCTest
@testable import MurinookMacIntegration

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    func testSlowConsumerReceivesEveryObservedGeneration() async throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MurinookMonitorTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let monitor = ClipboardMonitor(pasteboard: pasteboard, policy: ClipboardCapturePolicy(), writeRegistry: ClipboardWriteRegistry())
        defer { monitor.stop() }
        let stream = monitor.start(pollInterval: 0.02)

        for value in ["first", "second", "third"] {
            pasteboard.clearContents()
            pasteboard.setString(value, forType: .string)
            try await Task.sleep(for: .milliseconds(100))
        }

        var iterator = stream.makeAsyncIterator()
        var captured: [String] = []
        for _ in 0..<3 {
            guard let generation = await iterator.next(),
                  let data = generation.items.first?.representations.first?.data,
                  let value = String(data: data, encoding: .utf8) else {
                XCTFail("Expected each observed clipboard generation to remain buffered")
                return
            }
            captured.append(value)
        }
        XCTAssertEqual(captured, ["first", "second", "third"])
    }
}

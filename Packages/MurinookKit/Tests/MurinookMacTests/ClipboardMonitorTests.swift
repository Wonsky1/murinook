import AppKit
import XCTest
@testable import MurinookMacIntegration

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    func testReplacingStreamCannotBeStoppedByPreviousStreamsTermination() async {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MurinookMonitorRestartTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let monitor = ClipboardMonitor(pasteboard: pasteboard, policy: ClipboardCapturePolicy(), writeRegistry: ClipboardWriteRegistry())
        defer { monitor.stop() }
        let previous = monitor.start(pollInterval: 0.05)
        let replacement = monitor.start(pollInterval: 0.05)

        pasteboard.clearContents()
        pasteboard.setString("new copy after restart", forType: .string)
        let snapshot = await nextSnapshot(in: replacement)
        XCTAssertEqual(text(in: snapshot), "new copy after restart")
        withExtendedLifetime(previous) {}
    }

    func testResumeIgnoresCopiesMadeWhileCaptureWasStopped() async {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MurinookMonitorPausedTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let monitor = ClipboardMonitor(pasteboard: pasteboard, policy: ClipboardCapturePolicy(), writeRegistry: ClipboardWriteRegistry())
        defer { monitor.stop() }
        monitor.stop()
        pasteboard.clearContents()
        pasteboard.setString("private copy while disabled", forType: .string)
        let stream = monitor.start(pollInterval: 0.05)

        // A negative assertion needs a bounded observation interval. Four timer
        // intervals allow the existing generation to be noticed if it leaks.
        let snapshot = await nextSnapshot(in: stream, timeout: .milliseconds(200))
        XCTAssertNil(snapshot, "Enabling capture must establish a fresh pasteboard baseline")
    }

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

    private func nextSnapshot(in stream: AsyncStream<ClipboardSnapshot>, timeout: Duration = .seconds(1)) async -> ClipboardSnapshot? {
        await withTaskGroup(of: ClipboardSnapshot?.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next()
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    private func text(in snapshot: ClipboardSnapshot?) -> String? {
        guard let data = snapshot?.items.first?.representations.first?.data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

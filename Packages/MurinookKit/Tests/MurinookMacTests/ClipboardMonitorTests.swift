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

    func testSlowConsumerReceivesEveryPolledGeneration() async {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MurinookMonitorTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let polling = ManualClipboardPolling()
        let monitor = ClipboardMonitor(pasteboard: pasteboard, policy: ClipboardCapturePolicy(), writeRegistry: ClipboardWriteRegistry(), polling: polling)
        defer { monitor.stop() }
        let stream = monitor.start(pollInterval: 0.02)

        for value in ["first", "second", "third"] {
            pasteboard.clearContents()
            pasteboard.setString(value, forType: .string)
            polling.fire()
        }

        var captured: [String] = []
        for _ in 0..<3 {
            guard let generation = await nextSnapshot(in: stream, timeout: .seconds(1)),
                  let value = text(in: generation) else {
                XCTFail("Expected each manually observed clipboard generation to remain buffered")
                return
            }
            captured.append(value)
        }
        XCTAssertEqual(captured, ["first", "second", "third"])
    }

    func testWritesBetweenPollsCoalesceToLatestPasteboardGeneration() async {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MurinookMonitorCoalescingTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let polling = ManualClipboardPolling()
        let monitor = ClipboardMonitor(pasteboard: pasteboard, policy: ClipboardCapturePolicy(), writeRegistry: ClipboardWriteRegistry(), polling: polling)
        defer { monitor.stop() }
        let stream = monitor.start(pollInterval: 0.02)

        for value in ["first", "second", "third"] {
            pasteboard.clearContents()
            pasteboard.setString(value, forType: .string)
        }
        polling.fire()

        let snapshot = await nextSnapshot(in: stream, timeout: .milliseconds(250))
        XCTAssertEqual(text(in: snapshot), "third")
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

@MainActor
private final class ManualClipboardPolling: ClipboardPolling {
    private var tick: (@MainActor @Sendable () -> Void)?

    func start(interval: TimeInterval, tick: @escaping @MainActor @Sendable () -> Void) {
        self.tick = tick
    }

    func stop() {
        tick = nil
    }

    func fire() {
        tick?()
    }
}

import AppKit
import XCTest
import MurinookDomain
@testable import MurinookMacIntegration

@MainActor
final class ShortcutRecorderTests: XCTestCase {
    func testRecordsBareKeyAndReleasesCallbacksAfterward() {
        let recorder = ShortcutRecorder()
        let window = makeWindow()
        var recorded: KeyCombination?
        var cancelled = false
        recorder.begin(window: window, onCancel: { cancelled = true }) { recorded = $0 }

        recorder.consume(makeEvent(keyCode: 122, flags: []), in: window)

        XCTAssertEqual(recorded, KeyCombination(keyCode: 122, modifiers: []))
        XCTAssertFalse(cancelled)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertNil(recorder.onRecord)
    }

    func testIgnoresEventsFromAnotherWindow() {
        let recorder = ShortcutRecorder()
        let window = makeWindow()
        let otherWindow = makeWindow()
        var recorded: KeyCombination?
        recorder.begin(window: window, onCancel: {}) { recorded = $0 }

        recorder.consume(makeEvent(keyCode: 122, flags: [.command]), in: otherWindow)

        XCTAssertNil(recorded)
        XCTAssertTrue(recorder.isRecording)
        recorder.cancel()
    }

    func testUnmodifiedEscapeCancelsAndInvokesCancellationCallback() {
        let recorder = ShortcutRecorder()
        let window = makeWindow()
        var cancelled = 0
        var recorded: KeyCombination?
        recorder.begin(window: window, onCancel: { cancelled += 1 }) { recorded = $0 }

        recorder.consume(makeEvent(keyCode: 53, flags: []), in: window)

        XCTAssertEqual(cancelled, 1)
        XCTAssertNil(recorded)
        XCTAssertFalse(recorder.isRecording)
    }

    func testModifiedEscapeCanBeRecorded() {
        let recorder = ShortcutRecorder()
        let window = makeWindow()
        var recorded: KeyCombination?
        recorder.begin(window: window, onCancel: {}) { recorded = $0 }

        recorder.consume(makeEvent(keyCode: 53, flags: [.command]), in: window)

        XCTAssertEqual(recorded, KeyCombination(keyCode: 53, modifiers: .command))
    }

    func testPureModifierKeyIsIgnored() {
        let recorder = ShortcutRecorder()
        let window = makeWindow()
        var recorded: KeyCombination?
        recorder.begin(window: window, onCancel: {}) { recorded = $0 }

        recorder.consume(makeEvent(keyCode: 55, flags: [.command]), in: window)

        XCTAssertNil(recorded)
        XCTAssertTrue(recorder.isRecording)
        recorder.cancel()
    }

    func testRepeatedCancelIsIdempotentAndReleasesCancellationCallback() {
        let recorder = ShortcutRecorder()
        let window = makeWindow()
        recorder.begin(window: window, onCancel: {}) { _ in }

        recorder.cancel()
        recorder.cancel()

        XCTAssertFalse(recorder.isRecording)
        XCTAssertNil(recorder.onRecord)
    }

    private func makeWindow() -> NSWindow {
        NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered, defer: true)
    }

    private func makeEvent(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: keyCode)!
    }
}

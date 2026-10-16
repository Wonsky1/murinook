import AppKit
import MurinookDomain

/// Records one local key combination while active. The monitor is removed on commit or cancel.
@MainActor
public final class ShortcutRecorder {
    public var onRecord: (@MainActor (KeyCombination) -> Void)?
    public var onCancel: (@MainActor () -> Void)?

    private var monitor: Any?
    private weak var recordingWindow: NSWindow?

    public init() {}

    public var isRecording: Bool { monitor != nil }

    public func begin(
        window: NSWindow,
        onCancel: @escaping @MainActor () -> Void,
        onRecord: @escaping @MainActor (KeyCombination) -> Void
    ) {
        cancel()
        recordingWindow = window
        self.onCancel = onCancel
        self.onRecord = onRecord
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
            guard let window, event.window === window else { return event }
            MainActor.assumeIsolated {
                self?.consume(event, in: window)
            }
            return nil
        }
    }

    public func cancel() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        recordingWindow = nil
        onRecord = nil
        onCancel = nil
    }

    /// Handles the same event path used by the local monitor, allowing native event behavior to be exercised.
    func consume(_ event: NSEvent, in window: NSWindow) {
        guard monitor != nil, recordingWindow === window else { return }
        let keyCode = UInt32(event.keyCode)
        guard !Self.modifierKeyCodes.contains(keyCode) else { return }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let modifiers = shortcutModifiers(from: flags)

        if keyCode == 53, modifiers.isEmpty {
            let callback = onCancel
            cancel()
            callback?()
            return
        }

        let callback = onRecord
        cancel()
        callback?(KeyCombination(keyCode: keyCode, modifiers: modifiers))
    }

    private func shortcutModifiers(from flags: NSEvent.ModifierFlags) -> ShortcutModifiers {
        var raw: UInt32 = 0
        if flags.contains(.command) { raw |= 1 << 0 }
        if flags.contains(.option) { raw |= 1 << 1 }
        if flags.contains(.control) { raw |= 1 << 2 }
        if flags.contains(.shift) { raw |= 1 << 3 }
        return ShortcutModifiers(rawValue: raw)
    }

    private static let modifierKeyCodes: Set<UInt32> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
}

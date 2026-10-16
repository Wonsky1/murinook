import AppKit
import Combine

/// Activation is asynchronous for menu bar apps. Only the latest requested window
/// should receive focus when macOS finishes activating the application.
@MainActor final class WindowForegroundCoordinator {
    private weak var pendingWindow: NSWindow?
    private var activation: AnyCancellable?
    private let onPresentation: (String, NSWindow) -> Void

    init(onPresentation: @escaping (String, NSWindow) -> Void = { _, _ in }) {
        self.onPresentation = onPresentation
        activation = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.finishPresentation() }
            }
    }

    func request(_ window: NSWindow) {
        pendingWindow = window
        onPresentation("requested", window)
        // These requests follow launch/reopen or an explicit window action. The
        // cooperative activate() call can leave an accessory app behind Finder.
        NSApp.activate(ignoringOtherApps: true)
        if NSApp.isActive { finishPresentation() }
    }

    func cancel(_ window: NSWindow) {
        if pendingWindow === window { pendingWindow = nil }
    }

    func cancelAll() { pendingWindow = nil }

    private func finishPresentation() {
        guard NSApp.isActive, let window = pendingWindow else { return }
        pendingWindow = nil
        guard window.isVisible, !window.ignoresMouseEvents else { return }
        window.makeKeyAndOrderFront(nil)
        onPresentation("completed", window)
    }
}

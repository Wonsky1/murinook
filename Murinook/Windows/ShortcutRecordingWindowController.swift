import AppKit
import MurinookDomain
import MurinookMacIntegration
import SwiftUI

@MainActor
final class ShortcutRecordingWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let recorder = ShortcutRecorder()
    private let state = ShortcutRecordingState()
    private let save: (KeyCombination) -> String?
    private var didClose: (() -> Void)?

    init(action: ShortcutAction, current: KeyCombination?, locale: Locale,
         save: @escaping (KeyCombination) -> String?, didClose: @escaping () -> Void) {
        self.save = save
        self.didClose = didClose
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = AppStrings.text("Keyboard shortcut", locale: locale)
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        RelayWindowChrome.configure(window, content: AnyView(ShortcutRecordingView(state: state,
            action: action, current: current, locale: locale,
            recordAgain: { [weak self] in self?.begin() },
            cancel: { [weak self] in self?.close() },
            save: { [weak self] in self?.commit() })), allowsMinimize: false, allowsZoom: false)
        window.center()
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        begin()
    }

    func close() { window.close() }

    func windowWillClose(_ notification: Notification) {
        recorder.cancel()
        let callback = didClose
        didClose = nil
        callback?()
    }

    private func begin() {
        state.candidate = nil
        state.errorMessage = nil
        recorder.begin(window: window, onCancel: { [weak self] in self?.close() }) { [weak self] combination in
            self?.state.candidate = combination
        }
    }

    private func commit() {
        guard let candidate = state.candidate else { return }
        if let error = save(candidate) { state.errorMessage = error }
        else { close() }
    }
}

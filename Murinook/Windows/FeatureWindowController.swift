import AppKit
import SwiftUI

@MainActor final class FeatureWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let visibility = WindowVisibilityAnimator()
    private let foreground: WindowForegroundCoordinator
    private let onClose: (() -> Void)?

    init(title: String, size: NSSize, minimumSize: NSSize, content: AnyView, foreground: WindowForegroundCoordinator, integratedTitlebar: Bool = true, autosaveName: String? = nil, onClose: (() -> Void)? = nil) {
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        self.onClose = onClose
        self.foreground = foreground
        super.init()
        window.delegate = self
        if integratedTitlebar {
            RelayWindowChrome.configure(window, content: content)
        } else {
            window.contentView = NSHostingView(rootView: content)
        }
        window.title = title
        window.minSize = minimumSize
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName(autosaveName ?? title)
    }

    func setTitle(_ title: String) { window.title = title }

    func show() {
        window.collectionBehavior.insert(.moveToActiveSpace)
        let frame = WindowPresentationGeometry.visibleFrame(for: window.frame,
            screens: NSScreen.screens.map(\.visibleFrame), preferred: NSScreen.main?.visibleFrame)
        if frame != window.frame { window.setFrame(frame, display: false) }
        if window.isMiniaturized { window.deminiaturize(nil) }
        visibility.show(window)
        window.makeKeyAndOrderFront(nil)
        foreground.request(window)
    }

    func hide() { foreground.cancel(window); visibility.hide(window) }
    func close() { hide(); onClose?() }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        close()
        return false
    }
}

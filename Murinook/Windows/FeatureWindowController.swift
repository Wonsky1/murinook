import AppKit
import SwiftUI

final class FeatureWindowController {
    private let window: NSWindow
    private let visibility = WindowVisibilityAnimator()

    init(title: String, size: NSSize, minimumSize: NSSize, content: AnyView, integratedTitlebar: Bool = true, autosaveName: String? = nil) {
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
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

    func show() { NSApp.activate(); visibility.show(window); window.makeKeyAndOrderFront(nil) }
    func hide() { visibility.hide(window) }
}

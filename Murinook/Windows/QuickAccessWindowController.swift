import AppKit
import SwiftUI

final class QuickAccessWindowController {
    private let panel = FloatingPanel(size: NSSize(width: 900, height: 620))
    private let visibility = WindowVisibilityAnimator()
    private let dismissal = QuickAccessDismissalMonitor()

    init() { panel.closeAction = { [weak self] in self?.hide() } }

    func show(content: AnyView, title: String) {
        panel.title = title
        panel.contentView = NSHostingView(rootView: content)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            let bounds = screen.visibleFrame
            let size = NSSize(width: min(900, bounds.width), height: min(620, bounds.height))
            panel.setFrame(NSRect(x: bounds.midX - size.width / 2, y: bounds.minY + 48,
                width: size.width, height: size.height), display: true)
        }
        visibility.show(panel)
        panel.makeKeyAndOrderFront(nil)
        dismissal.start(panel: panel) { [weak self] in self?.hide() }
    }

    func setTitle(_ title: String) { panel.title = title }

    func hide() {
        visibility.hide(panel)
        dismissal.stop()
    }
}

import AppKit
/// SwiftUI may render a menu label without a live child view. Resolve the app's
/// single visible status window through public AppKit geometry instead.
@MainActor final class MenuBarAnchor {
    var availableView: NSView? {
        let candidates = NSApp.windows.compactMap { window -> NSView? in
            guard window.level == .statusBar, window.isVisible,
                  window.frame.height <= NSStatusBar.system.thickness + 8,
                  let view = window.contentView, !view.bounds.isEmpty else { return nil }
            let rect = window.convertToScreen(view.convert(view.bounds, to: nil))
            let center = NSPoint(x: rect.midX, y: rect.midY)
            guard NSScreen.screens.contains(where: { $0.frame.contains(center) }) else { return nil }
            return view
        }
        // Hidden/crowded menu bars or multiple candidates use the top-right fallback.
        return candidates.count == 1 ? candidates[0] : nil
    }
}

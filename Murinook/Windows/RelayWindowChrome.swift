import AppKit
import MurinookDesignSystem
import SwiftUI

@MainActor
enum RelayWindowChrome {
    static func configure(
        _ window: NSWindow,
        content: AnyView,
        allowsMinimize: Bool = true,
        allowsZoom: Bool = true
    ) {
        window.styleMask.insert([.titled, .closable, .fullSizeContentView])
        if allowsMinimize {
            window.styleMask.insert(.miniaturizable)
        } else {
            window.styleMask.remove(.miniaturizable)
        }

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true

        for button: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }

        let actions = MurinookWindowActions(
            close: { [weak window] in window?.performClose(nil) },
            minimize: { [weak window] in window?.performMiniaturize(nil) },
            zoom: { [weak window] in window?.performZoom(nil) },
            canMinimize: allowsMinimize,
            canZoom: allowsZoom
        )
        let rootView = content
            .environment(\.murinookWindowActions, actions)
            .ignoresSafeArea(.container, edges: .top)
        window.contentView = RelayMovableHostingView(rootView: AnyView(rootView))
    }
}

private final class RelayMovableHostingView: NSHostingView<AnyView> {
    override var mouseDownCanMoveWindow: Bool {
        guard let window else { return false }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let distanceFromTop = isFlipped ? point.y - bounds.minY : bounds.maxY - point.y
        // Drag the header, while keeping selection and content drags in the body intact.
        return bounds.contains(point) && distanceFromTop >= 0 && distanceFromTop <= 50
    }
}

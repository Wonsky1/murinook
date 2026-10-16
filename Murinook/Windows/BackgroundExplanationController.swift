import AppKit
import SwiftUI

/// One-time education lives beside the menu icon, without resizable window chrome
/// or autosaved frames. If macOS hides the icon, use a compact top-right panel.
@MainActor final class BackgroundExplanationController: NSObject, NSPopoverDelegate {
    private let anchor: MenuBarAnchor
    private let popover = NSPopover()
    private let onDismiss: () -> Void
    private var fallback: BackgroundHintPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var isPresenting = false

    init(anchor: MenuBarAnchor, onDismiss: @escaping () -> Void) {
        self.anchor = anchor
        self.onDismiss = onDismiss
        super.init()
        popover.behavior = .transient
        popover.delegate = self
    }

    func show(content: AnyView) {
        guard !isPresenting else { return }
        let host = NSHostingController(rootView: content)
        let size = host.view.fittingSize
        isPresenting = true
        if let view = anchor.availableView {
            popover.contentViewController = host
            popover.contentSize = size
            popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        } else {
            showFallback(host: host, size: size)
        }
    }

    func dismiss() {
        guard isPresenting else { return }
        isPresenting = false
        popover.close()
        fallback?.orderOut(nil)
        fallback = nil
        removeMonitors()
        onDismiss()
    }

    /// Termination does not acknowledge education the user may not have read.
    func stop() {
        isPresenting = false
        popover.close()
        fallback?.orderOut(nil)
        fallback = nil
        removeMonitors()
    }

    func popoverDidClose(_ notification: Notification) { dismiss() }

    private func showFallback(host: NSViewController, size: NSSize) {
        let panel = BackgroundHintPanel(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentViewController = host
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 16
        panel.contentView?.layer?.masksToBounds = true
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            panel.setFrameTopLeftPoint(NSPoint(x: screen.visibleFrame.maxX - size.width - 12,
                                              y: screen.visibleFrame.maxY - 12))
        }
        fallback = panel
        panel.makeKeyAndOrderFront(nil)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { self.dismiss(); return nil }
            } else if event.window !== self.fallback {
                self.dismiss()
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in self?.dismiss() }
        }
    }

    private func removeMonitors() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
    }
}

private final class BackgroundHintPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

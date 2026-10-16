import AppKit

/// Observes both other applications and Murinook's own windows while Quick Access is visible.
@MainActor
final class QuickAccessDismissalMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start(panel: NSPanel, dismiss: @escaping @MainActor () -> Void) {
        stop()
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { _ in
            Task { @MainActor in dismiss() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents.union(.keyDown)) { [weak panel] event in
            // AppKit invokes local event monitors on the main thread, before responder handling.
            let consumed = MainActor.assumeIsolated {
                guard let panel, panel.isVisible else { return false }
                if event.type == .keyDown {
                    if event.keyCode == 53, event.window === panel || NSApp.keyWindow === panel {
                        dismiss()
                        return true
                    }
                } else if event.window !== panel {
                    // Filter/context menus are part of the interaction, even outside the panel frame.
                    if let window = event.window, window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue {
                        return false
                    }
                    dismiss()
                }
                return false
            }
            return consumed ? nil : event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }
}

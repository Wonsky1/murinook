import AppKit
import QuartzCore

/// Window visibility settles without allowing an old completion to hide a reopened window.
@MainActor final class WindowVisibilityAnimator {
    private var generation = 0

    func show(_ window: NSWindow) {
        generation &+= 1
        window.ignoresMouseEvents = false
        if !window.isVisible { window.alphaValue = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1 : 0 }
        window.orderFrontRegardless()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { window.alphaValue = 1; return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            window.animator().alphaValue = 1
        }
    }

    func hide(_ window: NSWindow) {
        generation &+= 1
        let current = generation
        window.ignoresMouseEvents = true
        guard window.isVisible else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            window.orderOut(nil); window.alphaValue = 1; return
        }
        // Relinquish keyboard focus immediately; fading must not intercept paste into another app.
        if window.isKeyWindow { window.resignKey() }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak window] in
            Task { @MainActor [weak self, weak window] in
                guard let self, let window, self.generation == current else { return }
                window.orderOut(nil)
                window.alphaValue = 1
            }
        })
    }
}

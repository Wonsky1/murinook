import AppKit
import SwiftUI

/// Brief feedback for a verified placement that met an app's size limit.
/// Never activates Murinook or interrupts the target app's keyboard focus.
@MainActor
final class WindowPlacementNotice {
    private var panel: PassivePlacementPanel?
    private var dismissal: Task<Void, Never>?

    func show(message: String, windowFrame: CGRect) {
        hide()
        guard let primary = NSScreen.screens.first else { return }
        let appKitFrame = CGRect(x: windowFrame.minX, y: primary.frame.maxY - windowFrame.maxY,
            width: windowFrame.width, height: windowFrame.height)
        let screen = NSScreen.screens.max {
            area($0.frame.intersection(appKitFrame)) < area($1.frame.intersection(appKitFrame))
        } ?? primary
        let visible = screen.visibleFrame
        let panel = panel ?? PassivePlacementPanel(contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        let host = NSHostingView(rootView: Text(message)
            .font(.system(size: 13, weight: .medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18).padding(.vertical, 13)
            .frame(width: min(360, max(1, visible.width - 32)))
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)))
        panel.contentView = host
        let size = host.fittingSize
        panel.setFrame(CGRect(x: visible.midX - size.width / 2,
            y: visible.minY + 28, width: size.width, height: size.height), display: true)
        self.panel = panel
        panel.orderFrontRegardless()
        dismissal = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            self?.hide()
        }
    }

    func hide() {
        dismissal?.cancel()
        dismissal = nil
        panel?.orderOut(nil)
    }

    private func area(_ rect: CGRect) -> CGFloat { rect.isNull ? 0 : rect.width * rect.height }
}

private final class PassivePlacementPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

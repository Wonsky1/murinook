import AppKit
import SwiftUI
import Observation
import MurinookDomain
import MurinookUseCases
import MurinookMacIntegration
import MurinookPresentation

@Observable final class ShelfWindowController {
    private let panel = FloatingPanel(size: NSSize(width: ShelfLayout.width, height: ShelfLayout.minimumHeight))
    private let tab = FloatingPanel(size: NSSize(width: 28, height: 48))
    private var state = ShelfPresentation()
    private var itemCount = 0
    private(set) var isDragging = false
    private var side: ShelfSide = .right
    private var offset: Double = 0.5
    private var screen: NSScreen?
    private var preferences: PreferencesStore?
    private var diagnostics: DragDiagnostics?
    private var lastLoggedWindowState: String?
    private let panelVisibility = WindowVisibilityAnimator()
    private let tabVisibility = WindowVisibilityAnimator()
    var placementChanged: ((ShelfSide, Double) -> Void)?

    init() {
        panel.closeAction = { [weak self] in self?.hide() }
        tab.closeAction = { [weak self] in self?.show() }
        NotificationCenter.default.addObserver(self, selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func configure(side: ShelfSide, offset: Double, itemCount: Int, preferences: PreferencesStore, diagnostics: DragDiagnostics? = nil, acceptDrop: @escaping (NSPasteboard) -> Bool,
                   isDropEnabled: @escaping () -> Bool, content: @escaping () -> AnyView) {
        self.side = side
        self.offset = offset
        self.preferences = preferences
        self.diagnostics = diagnostics
        // NSPanel already owns an empty content view; checking it for nil never installs the shelf.
        let destination = ShelfDropDestinationView(contentView: NSHostingView(rootView: content()), diagnostics: diagnostics)
        destination.onDrop = acceptDrop
        destination.isDropEnabled = isDropEnabled
        destination.onDragEntered = { [weak self] in self?.externalDragStarted() }
        panel.contentView = destination
        self.itemCount = itemCount
        state = ShelfPresentation(itemCount: itemCount)
        updateWindows()
    }

    func updatePlacement(side: ShelfSide, offset: Double) {
        self.side = side
        self.offset = offset
        updateWindows()
    }

    func itemsChanged(count: Int) {
        diagnostics?.event("shelf.items.changed", fields: ["before": String(itemCount), "after": String(count)])
        itemCount = count; state.itemsChanged(count: count); updateWindows()
    }
    func externalDragStarted() {
        diagnostics?.event("shelf.external_drag.started")
        screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        isDragging = true
        state.externalDragStarted()
        updateWindows()
    }
    func externalDragEnded() {
        diagnostics?.event("shelf.external_drag.ended")
        isDragging = false; state.externalDragEnded(); updateWindows()
    }
    func dropped(itemCount: Int) {
        diagnostics?.event("shelf.drop.succeeded", fields: ["item_count": String(itemCount)])
        self.itemCount = itemCount; isDragging = false; state.dropSucceeded(itemCount: itemCount); updateWindows()
    }
    func show() {
        diagnostics?.event("shelf.manual.show")
        state.restore()
        updateWindows()
        if state.mode == .expanded { panel.makeKeyAndOrderFront(nil) }
    }
    func hide() {
        diagnostics?.event("shelf.manual.hide")
        state.hide(); updateWindows()
    }

    func moveAnchor(to point: NSPoint) {
        guard let target = NSScreen.screens.first(where: { $0.frame.contains(point) }) else { return }
        screen = target
        side = point.x < target.frame.midX ? .left : .right
        offset = ShelfEdgeGeometry.normalizedOffset(forOrigin: NSPoint(x: point.x, y: point.y - panel.frame.height / 2),
            in: target.visibleFrame, panelSize: panel.frame.size)
        updateWindows()
    }

    func finishMoving() { placementChanged?(side, offset) }

    @objc private func screenConfigurationChanged() {
        if !NSScreen.screens.contains(where: { $0 === screen }) { screen = NSScreen.main }
        updateWindows()
    }

    private func updateWindows() {
        guard let display = screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let locale = preferences?.value.languageCode.map(Locale.init(identifier:)) ?? .current
        panel.title = AppStrings.text("Shelf", locale: locale)
        tab.title = AppStrings.text("Restore shelf", locale: locale)
        let bounds = display.visibleFrame
        let panelSize = NSSize(width: min(ShelfLayout.width, bounds.width), height: min(ShelfLayout.height(for: itemCount), bounds.height))
        let origin = ShelfEdgeGeometry.origin(in: bounds, panelSize: panelSize,
            side: side == .left ? .left : .right, normalizedOffset: offset)
        let y = origin.y
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
        tab.setFrame(NSRect(x: side == .right ? bounds.maxX - 28 : bounds.minX,
                            y: y + (panelSize.height - 48) / 2, width: 28, height: 48), display: true)
        switch state.mode {
        case .hidden:
            panelVisibility.hide(panel)
            tabVisibility.hide(tab)
        case .collapsed:
            if let preferences {
                tab.contentView = NSHostingView(rootView: FeatureEnvironment(preferences: preferences) {
                    ShelfRestoreTab(side: self.side, restore: { [weak self] in self?.show() })
                })
            }
            panelVisibility.hide(panel)
            tabVisibility.show(tab)
        case .expanded:
            tabVisibility.hide(tab)
            panelVisibility.show(panel)
        }
        let windowState = "\(state.mode)|\(panel.frame)|\(panel.isVisible)|\(tab.isVisible)|\(isDragging)|\(itemCount)"
        if windowState != lastLoggedWindowState {
            lastLoggedWindowState = windowState
            diagnostics?.event("shelf.window.state", fields: ["mode": String(describing: state.mode),
                "panel_frame": NSStringFromRect(panel.frame), "screen_frame": NSStringFromRect(display.frame),
                "visible_frame": NSStringFromRect(bounds), "panel_visible": String(panel.isVisible),
                "tab_visible": String(tab.isVisible), "dragging": String(isDragging), "item_count": String(itemCount),
                "window_number": String(panel.windowNumber), "key_window": String(panel.isKeyWindow)])
        }
    }

}

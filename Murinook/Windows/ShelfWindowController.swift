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
    private var isEnabled = true
    private(set) var isDragging = false
    private var position = ShelfPosition(x: 1, y: 0.5)
    private var positionLocked = false
    private var dragOffset: NSPoint?
    private var screen: NSScreen?
    private var preferences: PreferencesStore?
    private var diagnostics: DragDiagnostics?
    private var lastLoggedWindowState: String?
    private let panelVisibility = WindowVisibilityAnimator()
    private let tabVisibility = WindowVisibilityAnimator()
    var placementChanged: ((ShelfPosition) -> Void)?

    init() {
        panel.closeAction = { [weak self] in self?.hide() }
        tab.closeAction = { [weak self] in self?.show() }
        NotificationCenter.default.addObserver(self, selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func configure(position: ShelfPosition, positionLocked: Bool, itemCount: Int, preferences: PreferencesStore, diagnostics: DragDiagnostics? = nil, acceptDrop: @escaping (NSPasteboard) -> Bool,
                   isDropEnabled: @escaping () -> Bool, content: @escaping () -> AnyView) {
        self.position = position
        self.positionLocked = positionLocked
        self.preferences = preferences
        self.isEnabled = preferences.value.shelfEnabled
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

    func updatePlacement(position: ShelfPosition, locked: Bool) {
        self.position = position
        positionLocked = locked
        if locked { dragOffset = nil }
        updateWindows()
    }

    func itemsChanged(count: Int) {
        diagnostics?.event("shelf.items.changed", fields: ["before": String(itemCount), "after": String(count)])
        itemCount = count; state.itemsChanged(count: count); updateWindows()
    }
    func externalDragStarted() {
        guard isEnabled else { return }
        diagnostics?.event("shelf.external_drag.started")
        if screen == nil {
            screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        }
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
        guard isEnabled else { return }
        diagnostics?.event("shelf.manual.show")
        state.restore()
        updateWindows()
        if state.mode == .expanded { panel.makeKeyAndOrderFront(nil) }
    }
    func hide() {
        diagnostics?.event("shelf.manual.hide")
        state.hide(); updateWindows()
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        isDragging = false
        state = ShelfPresentation(itemCount: itemCount)
        updateWindows()
    }

    func beginMoving(at point: NSPoint) {
        guard !positionLocked else { return }
        dragOffset = NSPoint(x: point.x - panel.frame.minX, y: point.y - panel.frame.minY)
    }

    func move(to point: NSPoint) {
        guard !positionLocked, let dragOffset,
              let target = NSScreen.screens.first(where: { $0.frame.contains(point) }) else { return }
        screen = target
        let size = NSSize(width: min(ShelfLayout.width, target.visibleFrame.width),
            height: min(ShelfLayout.height(for: itemCount), target.visibleFrame.height))
        position = ShelfGeometry.normalizedPosition(
            forOrigin: NSPoint(x: point.x - dragOffset.x, y: point.y - dragOffset.y),
            in: target.visibleFrame, panelSize: size)
        updateWindows()
    }

    func finishMoving() {
        guard dragOffset != nil else { return }
        dragOffset = nil
        placementChanged?(position)
    }

    @objc private func screenConfigurationChanged() {
        if !NSScreen.screens.contains(where: { $0 === screen }) { screen = NSScreen.main }
        updateWindows()
    }

    private func updateWindows() {
        guard isEnabled else {
            panelVisibility.hide(panel)
            tabVisibility.hide(tab)
            return
        }
        guard let display = screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let locale = preferences?.value.languageCode.map(Locale.init(identifier:)) ?? .current
        panel.title = AppStrings.text("Shelf", locale: locale)
        tab.title = AppStrings.text("Restore shelf", locale: locale)
        let bounds = display.visibleFrame
        let panelSize = NSSize(width: min(ShelfLayout.width, bounds.width), height: min(ShelfLayout.height(for: itemCount), bounds.height))
        let origin = ShelfGeometry.origin(in: bounds, panelSize: panelSize, position: position)
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
        // The restore button stays beside the saved shelf location rather than
        // snapping back to an edge. Its own frame remains within usable bounds.
        let tabSize = NSSize(width: 32, height: 42)
        let tabOrigin = NSPoint(x: origin.x + (panelSize.width - tabSize.width) / 2,
            y: origin.y + (panelSize.height - tabSize.height) / 2)
        let tabPosition = ShelfGeometry.normalizedPosition(forOrigin: tabOrigin, in: bounds, panelSize: tabSize)
        tab.setFrame(NSRect(origin: ShelfGeometry.origin(in: bounds, panelSize: tabSize, position: tabPosition),
            size: tabSize), display: true)
        switch state.mode {
        case .hidden:
            panelVisibility.hide(panel)
            tabVisibility.hide(tab)
        case .collapsed:
            if let preferences {
                tab.contentView = NSHostingView(rootView: FeatureEnvironment(preferences: preferences) {
                    ShelfRestoreTab(restore: { [weak self] in self?.show() })
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

import AppKit
import SwiftUI

/// Tracks the original grab point, allowing free movement between displays.
struct ShelfMoveHandle: NSViewRepresentable {
    var isLocked: Bool
    var begin: (NSPoint) -> Void
    var move: (NSPoint) -> Void
    var finish: () -> Void

    func makeNSView(context: Context) -> HandleView {
        let view = HandleView()
        view.setAccessibilityElement(true)
        view.setAccessibilityLabel(AppStrings.text("Move shelf"))
        return view
    }
    func updateNSView(_ view: HandleView, context: Context) {
        view.isLocked = isLocked
        view.begin = begin
        view.window?.invalidateCursorRects(for: view)
        view.move = move
        view.finish = finish
    }

    final class HandleView: NSView {
        var isLocked = false
        var begin: ((NSPoint) -> Void)?
        var move: ((NSPoint) -> Void)?
        var finish: (() -> Void)?
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }
        override func resetCursorRects() { if !isLocked { addCursorRect(bounds, cursor: .openHand) } }
        override func mouseDown(with event: NSEvent) { if !isLocked { begin?(NSEvent.mouseLocation) } }
        override func mouseDragged(with event: NSEvent) { if !isLocked { move?(NSEvent.mouseLocation) } }
        override func mouseUp(with event: NSEvent) { finish?() }
    }
}

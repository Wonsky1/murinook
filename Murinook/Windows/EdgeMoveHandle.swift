import AppKit
import SwiftUI

/// The anchor tracks global pointer coordinates so it can move between displays.
struct EdgeMoveHandle: NSViewRepresentable {
    var move: (NSPoint) -> Void
    var finish: () -> Void

    func makeNSView(context: Context) -> HandleView {
        let view = HandleView()
        view.setAccessibilityElement(true)
        view.setAccessibilityLabel(AppStrings.text("Move shelf along screen edge"))
        return view
    }
    func updateNSView(_ view: HandleView, context: Context) {
        view.move = move
        view.finish = finish
    }

    final class HandleView: NSView {
        var move: ((NSPoint) -> Void)?
        var finish: (() -> Void)?
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
        override func mouseDragged(with event: NSEvent) { move?(NSEvent.mouseLocation) }
        override func mouseUp(with event: NSEvent) { finish?() }
    }
}

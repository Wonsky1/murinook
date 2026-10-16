import AppKit

enum WindowPresentationGeometry {
    /// Restored frames can refer to a disconnected display. Preserve the user's
    /// placement when possible, while keeping the title bar and controls reachable.
    static func visibleFrame(for frame: NSRect, screens: [NSRect], preferred: NSRect?) -> NSRect {
        guard !screens.isEmpty else { return frame }
        let intersecting = screens.max { lhs, rhs in
            intersectionArea(frame, lhs) < intersectionArea(frame, rhs)
        }
        let screen: NSRect
        if let intersecting, intersectionArea(frame, intersecting) > 0 {
            screen = intersecting
        } else {
            screen = preferred.flatMap { screens.contains($0) ? $0 : nil } ?? screens[0]
        }
        let size = NSSize(width: min(frame.width, screen.width), height: min(frame.height, screen.height))
        return NSRect(x: min(max(frame.minX, screen.minX), screen.maxX - size.width),
                      y: min(max(frame.minY, screen.minY), screen.maxY - size.height),
                      width: size.width, height: size.height)
    }

    private static func intersectionArea(_ lhs: NSRect, _ rhs: NSRect) -> CGFloat {
        let overlap = lhs.intersection(rhs)
        return overlap.isNull ? 0 : overlap.width * overlap.height
    }
}

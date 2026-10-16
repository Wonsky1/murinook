import AppKit

/// Template artwork lets macOS apply the menu bar's foreground automatically.
@MainActor enum MenuBarSymbol {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let arch = NSBezierPath()
            arch.lineWidth = 1.5
            arch.lineCapStyle = .round
            arch.move(to: NSPoint(x: 3.5, y: 2))
            arch.line(to: NSPoint(x: 3.5, y: 10))
            arch.curve(to: NSPoint(x: 14.5, y: 10), controlPoint1: NSPoint(x: 3.5, y: 18), controlPoint2: NSPoint(x: 14.5, y: 18))
            arch.line(to: NSPoint(x: 14.5, y: 2))
            arch.stroke()
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 7, y: 2, width: 4, height: 6), xRadius: 2, yRadius: 2).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Murinook"
        return image
    }()
}

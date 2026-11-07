import CoreGraphics
import MurinookDomain

/// All geometry is in logical points with AX's top-left origin. Scale factors
/// deliberately do not participate: AX and NSScreen both describe point frames.
struct WindowDisplay: Equatable {
    let id: UInt32
    let frame: CGRect
    let visibleFrame: CGRect
}

enum WindowGeometry {
    static func accessibilityFrame(fromAppKit frame: CGRect, primaryScreenTop: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryScreenTop - frame.maxY, width: frame.width, height: frame.height)
    }

    static func frame(for action: WindowAction, current: CGRect, visible: CGRect) throws -> CGRect {
        let halfWidth = visible.width / 2
        let halfHeight = visible.height / 2
        let thirdWidth = visible.width / 3
        switch action {
        case .leftHalf: return CGRect(x: visible.minX, y: visible.minY, width: halfWidth, height: visible.height)
        case .rightHalf: return CGRect(x: visible.minX + halfWidth, y: visible.minY, width: halfWidth, height: visible.height)
        case .topHalf: return CGRect(x: visible.minX, y: visible.minY, width: visible.width, height: halfHeight)
        case .bottomHalf: return CGRect(x: visible.minX, y: visible.minY + halfHeight, width: visible.width, height: halfHeight)
        case .topLeft: return CGRect(x: visible.minX, y: visible.minY, width: halfWidth, height: halfHeight)
        case .topRight: return CGRect(x: visible.minX + halfWidth, y: visible.minY, width: halfWidth, height: halfHeight)
        case .bottomLeft: return CGRect(x: visible.minX, y: visible.minY + halfHeight, width: halfWidth, height: halfHeight)
        case .bottomRight: return CGRect(x: visible.minX + halfWidth, y: visible.minY + halfHeight, width: halfWidth, height: halfHeight)
        case .firstThird: return CGRect(x: visible.minX, y: visible.minY, width: thirdWidth, height: visible.height)
        case .centerThird: return CGRect(x: visible.minX + thirdWidth, y: visible.minY, width: thirdWidth, height: visible.height)
        case .lastThird: return CGRect(x: visible.minX + 2 * thirdWidth, y: visible.minY, width: thirdWidth, height: visible.height)
        case .maximize: return visible
        case .center:
            // Center is a move-only command, including for fixed-size windows.
            // Oversized windows keep their size and put the title bar at top-left.
            return CGRect(x: max(visible.minX, visible.midX - current.width / 2),
                          y: max(visible.minY, visible.midY - current.height / 2),
                          width: current.width, height: current.height)
        case .restore, .nextDisplay, .previousDisplay: throw WindowManagementError.operationFailed
        }
    }

    static func display(for frame: CGRect, among displays: [WindowDisplay]) throws -> WindowDisplay {
        guard let match = displays.max(by: { lhs, rhs in
            let leftArea = intersectionArea(frame, lhs.frame)
            let rightArea = intersectionArea(frame, rhs.frame)
            if leftArea == rightArea { return distanceSquared(frame, lhs.frame) > distanceSquared(frame, rhs.frame) }
            return leftArea < rightArea
        }) else { throw WindowManagementError.operationFailed }
        return match
    }

    static func adjacentDisplay(to display: WindowDisplay, among displays: [WindowDisplay], forward: Bool) throws -> WindowDisplay {
        let ordered = displays.sorted {
            if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
            if $0.frame.minY != $1.frame.minY { return $0.frame.minY < $1.frame.minY }
            return $0.id < $1.id
        }
        guard ordered.count > 1, let index = ordered.firstIndex(where: { $0.id == display.id }) else {
            throw WindowManagementError.noOtherDisplay
        }
        return ordered[(index + (forward ? 1 : ordered.count - 1)) % ordered.count]
    }

    static func transferred(_ frame: CGRect, from source: CGRect, to target: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return clamped(frame, to: target) }
        return clamped(CGRect(
            x: target.minX + (frame.minX - source.minX) / source.width * target.width,
            y: target.minY + (frame.minY - source.minY) / source.height * target.height,
            width: frame.width / source.width * target.width,
            height: frame.height / source.height * target.height
        ), to: target)
    }

    static func clamped(_ frame: CGRect, to visible: CGRect) -> CGRect {
        let width = min(frame.width, visible.width)
        let height = min(frame.height, visible.height)
        return CGRect(x: min(max(frame.minX, visible.minX), visible.maxX - width),
                      y: min(max(frame.minY, visible.minY), visible.maxY - height), width: width, height: height)
    }

    static func originClamped(_ frame: CGRect, to visible: CGRect) -> CGRect {
        CGRect(x: min(max(frame.minX, visible.minX), max(visible.minX, visible.maxX - frame.width)),
               y: min(max(frame.minY, visible.minY), max(visible.minY, visible.maxY - frame.height)),
               width: frame.width, height: frame.height)
    }

    static func restored(_ original: CGRect, previousDisplays: [WindowDisplay], currentDisplays: [WindowDisplay], canResize: Bool) throws -> CGRect {
        let originalDisplay = try display(for: original, among: previousDisplays)
        let occupied = previousDisplays.filter { !$0.frame.intersection(original).isNull }
        let relevant = occupied.isEmpty ? [originalDisplay] : occupied
        let arrangementUnchanged = relevant.allSatisfy { previous in
            currentDisplays.contains { $0.id == previous.id && $0.frame == previous.frame }
        }
        if arrangementUnchanged { return original }
        let destination = try currentDisplays.first(where: { $0.id == originalDisplay.id })
            ?? display(for: original, among: currentDisplays)
        let relocated: CGRect
        if destination.id == originalDisplay.id {
            relocated = original.offsetBy(dx: destination.frame.minX - originalDisplay.frame.minX,
                                          dy: destination.frame.minY - originalDisplay.frame.minY)
        } else {
            relocated = original
        }
        return canResize ? clamped(relocated, to: destination.visibleFrame) : originClamped(relocated, to: destination.visibleFrame)
    }

    static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }

    static func isUsable(_ frame: CGRect) -> Bool {
        frame.minX.isFinite && frame.minY.isFinite && frame.width.isFinite && frame.height.isFinite
            && frame.width > 0 && frame.height > 0
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private static func distanceSquared(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let x = lhs.midX - rhs.midX
        let y = lhs.midY - rhs.midY
        return x * x + y * y
    }
}

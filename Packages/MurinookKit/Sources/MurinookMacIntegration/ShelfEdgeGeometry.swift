import CoreGraphics
import MurinookDomain

/// Pure placement math for an edge-attached shelf panel.
public enum ShelfEdgeGeometry {
    public static func origin(
        in bounds: CGRect,
        panelSize: CGSize,
        side: ShelfSide,
        normalizedOffset: CGFloat
    ) -> CGPoint {
        let width = min(max(0, panelSize.width), max(0, bounds.width))
        let height = min(max(0, panelSize.height), max(0, bounds.height))
        let availableY = max(0, bounds.height - height)
        let offset = normalizedOffset.isFinite ? min(max(normalizedOffset, 0), 1) : 0
        let x = side == .left ? bounds.minX : bounds.maxX - width
        return CGPoint(x: x, y: bounds.minY + availableY * offset)
    }

    public static func normalizedOffset(forOrigin origin: CGPoint, in bounds: CGRect, panelSize: CGSize) -> CGFloat {
        let availableY = max(0, bounds.height - min(max(0, panelSize.height), max(0, bounds.height)))
        guard availableY > 0, origin.y.isFinite else { return 0.5 }
        return min(max((origin.y - bounds.minY) / availableY, 0), 1)
    }
}

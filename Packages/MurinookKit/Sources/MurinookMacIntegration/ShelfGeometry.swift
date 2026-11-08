import CoreGraphics
import MurinookDomain

/// Pure placement math for a shelf panel positioned anywhere inside a display's usable frame.
public enum ShelfGeometry {
    public static func origin(in bounds: CGRect, panelSize: CGSize, position: ShelfPosition) -> CGPoint {
        let position = ShelfPosition(x: position.x, y: position.y)
        let width = boundedDimension(panelSize.width, by: bounds.width)
        let height = boundedDimension(panelSize.height, by: bounds.height)
        let availableX = max(0, finiteDimension(bounds.width) - width)
        let availableY = max(0, finiteDimension(bounds.height) - height)
        return CGPoint(x: bounds.minX + availableX * CGFloat(position.x),
                       y: bounds.minY + availableY * CGFloat(position.y))
    }

    public static func normalizedPosition(forOrigin origin: CGPoint, in bounds: CGRect, panelSize: CGSize) -> ShelfPosition {
        let width = boundedDimension(panelSize.width, by: bounds.width)
        let height = boundedDimension(panelSize.height, by: bounds.height)
        let availableX = max(0, finiteDimension(bounds.width) - width)
        let availableY = max(0, finiteDimension(bounds.height) - height)
        let x = availableX > 0 && origin.x.isFinite ? (origin.x - bounds.minX) / availableX : 0.5
        let y = availableY > 0 && origin.y.isFinite ? (origin.y - bounds.minY) / availableY : 0.5
        return ShelfPosition(x: Double(x), y: Double(y))
    }

    private static func boundedDimension(_ dimension: CGFloat, by bound: CGFloat) -> CGFloat {
        min(finiteDimension(dimension), finiteDimension(bound))
    }

    private static func finiteDimension(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(0, value) : 0
    }
}

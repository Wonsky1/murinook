import CoreGraphics

public enum WindowPlacementResult: Equatable, Sendable {
    case exact
    /// The app accepted a larger size, verified at the requested screen edge.
    case sizeConstrained(frame: CGRect)
}

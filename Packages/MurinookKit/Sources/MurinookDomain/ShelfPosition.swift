import Foundation

/// Normalized placement inside a display's usable frame.
/// `x` runs from left to right; `y` runs from bottom to top.
public struct ShelfPosition: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = Self.normalized(x)
        self.y = Self.normalized(y)
    }

    private static func normalized(_ value: Double) -> Double {
        guard value.isFinite else { return 0.5 }
        return min(max(value, 0), 1)
    }

    private enum CodingKeys: String, CodingKey { case x, y }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try container.decodeIfPresent(Double.self, forKey: .x) ?? 0.5,
                  y: try container.decodeIfPresent(Double.self, forKey: .y) ?? 0.5)
    }
}

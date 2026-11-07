import Foundation

public enum WindowAction: String, CaseIterable, Codable, Sendable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case firstThird
    case centerThird
    case lastThird
    case maximize
    case center
    case restore
    case nextDisplay
    case previousDisplay
}

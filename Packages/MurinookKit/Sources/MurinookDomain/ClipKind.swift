import Foundation

public enum ClipKind: String, Codable, CaseIterable, Sendable {
    case text, link, image, file, code, color

    public var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .file: "doc"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .color: "paintpalette"
        }
    }
}

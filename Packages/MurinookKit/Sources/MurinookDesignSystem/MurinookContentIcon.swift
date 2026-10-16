import AppKit
import SwiftUI

public struct MurinookContentIcon: View {
    private let data: Data?
    private let kindIdentifier: String
    private let symbol: String
    private let size: CGFloat
    @State private var image: NSImage?

    public init(data: Data?, kindIdentifier: String, symbol: String, size: CGFloat) {
        self.data = data; self.kindIdentifier = kindIdentifier; self.symbol = symbol; self.size = size
    }

    public var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit().frame(width: size, height: size)
            } else {
                MurinookKindBadge(kindIdentifier: kindIdentifier, symbol: symbol, size: size)
            }
        }
        .accessibilityHidden(true)
        .task(id: data) { image = data.flatMap(NSImage.init(data:)) }
    }
}

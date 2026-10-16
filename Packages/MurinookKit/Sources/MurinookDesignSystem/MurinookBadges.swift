import AppKit
import SwiftUI

public struct MurinookSymbolBadge: View {
    public let symbol: String
    public let label: Text

    public init(symbol: String, label: Text) { self.symbol = symbol; self.label = label }

    public var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(MurinookPalette.accent)
            .frame(width: 34, height: 34)
            .background(MurinookPalette.accentSoft, in: RoundedRectangle(cornerRadius: 9))
            .accessibilityLabel(label)
    }
}

public struct MurinookKindBadge: View {
    public let kindIdentifier: String
    public let symbol: String
    private let size: CGFloat

    public init(kindIdentifier: String, symbol: String, size: CGFloat = 39) {
        self.kindIdentifier = kindIdentifier; self.symbol = symbol; self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(MurinookPalette.kindBackground(kindIdentifier))
            kindGlyph.foregroundStyle(MurinookPalette.kindForeground(kindIdentifier))
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(LocalizedStringKey("kind." + kindIdentifier), bundle: .module))
    }

    @ViewBuilder private var kindGlyph: some View {
        switch kindIdentifier {
        case "text": Text("Aa").font(.system(size: 15, weight: .bold))
        case "image":
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [Color(murinookHex: 0xb0d0cb), Color(murinookHex: 0x557f72), Color(murinookHex: 0x28615b)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().fill(Color(murinookHex: 0xf3d4a0)).frame(width: 5, height: 5).offset(x: 6, y: -10)
            }.frame(width: 25, height: 19).clipShape(RoundedRectangle(cornerRadius: 3))
        case "link": Text("↗").font(.system(size: 20, weight: .regular))
        case "code": Text("</>").font(.system(size: 11, weight: .medium, design: .monospaced))
        case "color": RoundedRectangle(cornerRadius: 5).fill(MurinookPalette.accent).frame(width: 20, height: 20)
        default: Image(systemName: symbol).font(.system(size: 15, weight: .medium))
        }
    }
}

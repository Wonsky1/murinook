import SwiftUI

/// The Relay arch stays quiet at toolbar scale; its small inner door is the brand cue.
public struct MurinookBrandMark: View {
    public let size: CGFloat
    public init(size: CGFloat) { self.size = size }

    public var body: some View {
        Canvas { context, dimensions in
            let scale = min(dimensions.width, dimensions.height) / 28
            context.scaleBy(x: scale, y: scale)
            var arch = Path()
            arch.move(to: CGPoint(x: 5, y: 25))
            arch.addLine(to: CGPoint(x: 5, y: 12))
            arch.addCurve(to: CGPoint(x: 23, y: 12), control1: CGPoint(x: 5, y: 0), control2: CGPoint(x: 23, y: 0))
            arch.addLine(to: CGPoint(x: 23, y: 25))
            context.stroke(arch, with: .color(MurinookPalette.accent), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            let door = Path(roundedRect: CGRect(x: 11, y: 16, width: 6, height: 10), cornerRadius: 3)
            context.fill(door, with: .color(MurinookPalette.accent.opacity(0.65)))
        }
        .padding(size * 0.2)
        .frame(width: size, height: size)
        .background(MurinookPalette.surface2, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .accessibilityHidden(true)
    }
}

extension Color {
    init(murinookHex hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255, opacity: 1)
    }
}

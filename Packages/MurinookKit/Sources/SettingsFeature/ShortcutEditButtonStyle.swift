import MurinookDesignSystem
import SwiftUI

struct ShortcutEditButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ShortcutEditButtonLabel(configuration: configuration)
    }
}

private struct ShortcutEditButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    private var highlighted: Bool { isEnabled && (isHovered || configuration.isPressed) }

    var body: some View {
        configuration.label
            .foregroundStyle(isEnabled ? MurinookPalette.accent : MurinookPalette.muted)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(highlighted ? MurinookPalette.accent.opacity(configuration.isPressed ? 0.24 : 0.16) : MurinookPalette.accentSoft,
                        in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(MurinookPalette.accent.opacity(highlighted ? 0.5 : 0), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 9))
            .onHover { isHovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: highlighted)
    }
}

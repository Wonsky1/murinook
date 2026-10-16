import SwiftUI
import MurinookDomain
import MurinookDesignSystem

struct ShelfRestoreTab: View {
    let side: ShelfSide
    let restore: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            if side == .right { Spacer(minLength: 0) }
            Button(action: restore) {
                Image(systemName: side == .right ? "chevron.left" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: hovering ? 28 : 22, height: 48)
                    .foregroundStyle(MurinookPalette.accent)
                    .background(MurinookPalette.surface, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(MurinookPalette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppStrings.text("Restore shelf", locale: locale))
            .help(AppStrings.text("Restore shelf", locale: locale))
            if side == .left { Spacer(minLength: 0) }
        }
        .frame(width: 28, height: 48)
        .onHover { hovering = $0 }
        .animation(MurinookMotion.settle(reduceMotion: reduceMotion), value: hovering)
    }
}

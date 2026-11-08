import SwiftUI
import MurinookDomain
import MurinookDesignSystem

struct ShelfRestoreTab: View {
    let restore: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: restore) {
                Image(systemName: "tray.full")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: hovering ? 32 : 26, height: hovering ? 42 : 36)
                    .foregroundStyle(MurinookPalette.accent)
                    .background(MurinookPalette.surface, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(MurinookPalette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppStrings.text("Restore shelf", locale: locale))
            .help(AppStrings.text("Restore shelf", locale: locale))
        }
        .frame(width: 32, height: 42)
        .onHover { hovering = $0 }
        .animation(MurinookMotion.settle(reduceMotion: reduceMotion), value: hovering)
    }
}

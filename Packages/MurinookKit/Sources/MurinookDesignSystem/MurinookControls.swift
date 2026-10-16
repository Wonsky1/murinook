import AppKit
import SwiftUI

public struct MurinookPill: View {
    private let title: Text
    private let isSelected: Bool
    private let action: () -> Void

    public init(title: Text, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title; self.isSelected = isSelected; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            title.font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? MurinookPalette.accent : MurinookPalette.muted)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(isSelected ? MurinookPalette.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}

public struct MurinookButtonStyle: ButtonStyle {
    public enum Variant { case primary, quiet, danger }
    private let variant: Variant
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(variant: Variant = .quiet) { self.variant = variant }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(background.opacity(configuration.isPressed ? 0.88 : 1), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(MurinookMotion.feedback(reduceMotion: reduceMotion), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant { case .primary: MurinookPalette.onAccent; case .quiet: MurinookPalette.text; case .danger: MurinookPalette.danger }
    }
    private var background: Color {
        switch variant { case .primary: MurinookPalette.accent; case .quiet: MurinookPalette.page; case .danger: MurinookPalette.danger.opacity(0.08) }
    }
    private var border: Color {
        switch variant { case .primary: MurinookPalette.accent; case .quiet: MurinookPalette.border; case .danger: MurinookPalette.danger.opacity(0.3) }
    }
}

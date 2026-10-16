import MurinookDesignSystem
import MurinookDomain
import MurinookMacIntegration
import SwiftUI

struct ShortcutRecordingView: View {
    let state: ShortcutRecordingState
    let action: ShortcutAction
    let current: KeyCombination?
    let locale: Locale
    let recordAgain: () -> Void
    let cancel: () -> Void
    let save: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                MurinookWindowControls()
                Image(systemName: "keyboard").font(.system(size: 20)).foregroundStyle(MurinookPalette.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(text("shortcut." + action.rawValue)).font(.system(size: 16, weight: .semibold))
                    Text(text("Press a key or key combination. Escape cancels recording."))
                        .font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
                }
                Spacer(minLength: 0)
            }
            Button(action: recordAgain) {
                HStack {
                    Text(state.candidate.map(ShortcutDescriptionFormatter.string(for:)) ?? text("Press your new keyboard shortcut"))
                        .font(.system(size: state.candidate == nil ? 13 : 26, weight: .medium, design: .monospaced))
                    if state.candidate != nil { Image(systemName: "pencil").font(.system(size: 12)) }
                }
                .frame(maxWidth: .infinity, minHeight: 76)
                .background(MurinookPalette.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MurinookPalette.accent.opacity(0.35)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(MurinookPalette.accent)
            .accessibilityLabel(text("Record again"))
            .accessibilityValue(state.candidate.map(ShortcutDescriptionFormatter.string(for:)) ?? text("Press your new keyboard shortcut"))
            Text(text("Current shortcut") + ": " + (current.map(ShortcutDescriptionFormatter.string(for:)) ?? text("Disabled")))
                .font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
            Text(state.errorMessage ?? text("Single keys work system-wide too. Choose a key you do not need for regular typing."))
                .font(.system(size: 11)).foregroundStyle(state.errorMessage == nil ? MurinookPalette.muted : MurinookPalette.danger)
                .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 32)
                .accessibilityAddTraits(state.errorMessage == nil ? [] : .updatesFrequently)
            Spacer(minLength: 0)
            HStack {
                Button(text("Cancel"), action: cancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button(text("Save shortcut"), action: save)
                    .buttonStyle(.borderedProminent).tint(MurinookPalette.accent)
                    .keyboardShortcut(.defaultAction).disabled(state.candidate == nil)
            }
        }
        .padding(24)
        .foregroundStyle(MurinookPalette.text)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MurinookPalette.window)
    }

    private func text(_ key: String) -> String { AppStrings.text(key, locale: locale) }
}

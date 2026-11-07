import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct ShortcutSettingsRow: View {
    let action: ShortcutAction
    let store: PreferencesStore
    let actions: SettingsActions

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .foregroundStyle(MurinookPalette.accent)
                .frame(width: 30, height: 30)
                .background(MurinookPalette.accentSoft, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey("shortcut." + action.rawValue), bundle: .module)
                    .font(.system(size: 12, weight: .semibold))
                Text(LocalizedStringKey("shortcut.description." + action.rawValue), bundle: .module)
                    .font(.system(size: 11))
                    .foregroundStyle(MurinookPalette.muted)
                if actions.isShortcutUnavailable(action) {
                    Text("settings.shortcutUnavailable", bundle: .module)
                        .font(.system(size: 11)).foregroundStyle(MurinookPalette.warm)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Button { actions.recordShortcut(action) } label: {
                Group {
                    if let combination = store.value.shortcuts[action] {
                        Text(actions.shortcutDescription(combination))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    } else {
                        Text("settings.shortcutDisabled", bundle: .module)
                            .font(.system(size: 11))
                    }
                }
            }
            .buttonStyle(ShortcutEditButtonStyle())
            .accessibilityLabel(Text(LocalizedStringKey("shortcut." + action.rawValue), bundle: .module))
            .accessibilityValue(actions.shortcutDescription(store.value.shortcuts[action]))
            .accessibilityHint(Text("settings.recordShortcutHelp", bundle: .module))
            .help(Text("settings.recordShortcutHelp", bundle: .module))

            Button { actions.disableShortcut(action) } label: {
                Image(systemName: "xmark.circle").frame(width: 22, height: 28)
            }
            .buttonStyle(.plain).foregroundStyle(MurinookPalette.muted)
            .disabled(store.value.shortcuts[action] == nil)
            .accessibilityLabel(Text("settings.disableShortcut", bundle: .module))
            .help(Text("settings.disableShortcut", bundle: .module))

            Button { actions.resetShortcut(action) } label: {
                Image(systemName: "arrow.counterclockwise").frame(width: 22, height: 28)
            }
            .buttonStyle(.plain).foregroundStyle(MurinookPalette.muted)
            .disabled(store.value.shortcuts[action] == KeyCombination.defaults[action])
            .accessibilityLabel(Text("settings.resetShortcut", bundle: .module))
            .help(Text("settings.resetShortcut", bundle: .module))
        }
        .frame(minHeight: 60)
        .overlay(alignment: .top) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
    }

    private var icon: String {
        if action.windowAction != nil { return "macwindow" }
        return switch action {
        case .quickAccess: "sparkle.magnifyingglass"
        case .library: "clock"
        case .shelf: "tray"
        case .pasteNext: "arrowshape.turn.up.right"
        default: "keyboard"
        }
    }
}

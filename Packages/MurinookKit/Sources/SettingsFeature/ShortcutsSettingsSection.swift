import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct ShortcutsSettingsSection: View {
    let store: PreferencesStore
    let actions: SettingsActions

    var body: some View {
        SettingsGroup(key: "settings.clipboard.shortcuts", detail: "settings.clipboard.shortcutsDetail", icon: "keyboard") {
            VStack(spacing: 0) {
                ForEach([ShortcutAction.quickAccess, .library, .pasteNext], id: \.self) { action in
                    ShortcutSettingsRow(action: action, store: store, actions: actions)
                }
                Text("settings.shortcutHint", bundle: .module)
                    .font(.system(size: 11))
                    .foregroundStyle(MurinookPalette.soft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            }
        }
    }
}

import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct ShortcutsSettingsSection: View {
    let store: PreferencesStore
    let actions: SettingsActions

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ShortcutAction.applicationActions, id: \.self) { action in
                ShortcutSettingsRow(action: action, store: store, actions: actions)
                    .disabled(!featureEnabled(for: action))
                    .opacity(featureEnabled(for: action) ? 1 : 0.45)
            }
            Text("settings.shortcutHint", bundle: .module)
                .font(.system(size: 11))
                .foregroundStyle(MurinookPalette.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
        }
    }

    private func featureEnabled(for action: ShortcutAction) -> Bool {
        action == .shelf ? store.value.shelfEnabled : store.value.clipboardEnabled
    }
}

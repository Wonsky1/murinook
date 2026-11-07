import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct WindowManagementSettingsSection: View {
    let store: PreferencesStore
    let actions: SettingsActions

    private var isEnabled: Bool { store.value.windowManagementEnabled }

    var body: some View {
        VStack(spacing: 0) {
            FeatureEnableSettingsRow(store: store, key: "settings.windowManagement.enabled",
                detail: "settings.windowManagement.enabledDetail", icon: "macwindow", keyPath: \.windowManagementEnabled)
            options
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.45)
        }
    }

    private var options: some View {
        VStack(spacing: 0) {
            SettingsGroup(key: "settings.windowManagement.permission", detail: "settings.windowManagement.permissionDetail", icon: "accessibility") {
                PermissionSettingsControl(grantedKey: "settings.windowManagement.permissionGranted",
                    missingKey: "settings.windowManagement.permissionMissing",
                    check: actions.hasWindowAccessibilityAccess,
                    request: actions.requestWindowAccessibilityAccess, openSettings: actions.showAccessibilityHelp)
            }
            SettingsGroup(key: "settings.windowManagement.shortcuts", detail: "settings.windowManagement.shortcutsDetail", icon: "keyboard") {
                VStack(spacing: 0) {
                    ForEach(ShortcutAction.windowActions, id: \.self) { action in
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
}

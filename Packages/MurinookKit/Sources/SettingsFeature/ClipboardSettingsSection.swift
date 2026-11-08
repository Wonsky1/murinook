import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct ClipboardSettingsSection: View {
    let store: PreferencesStore
    let actions: SettingsActions
    let clearHistory: () -> Void
    let unpinnedHistoryCount: () -> Int

    private var isEnabled: Bool { store.value.clipboardEnabled }

    var body: some View {
        VStack(spacing: 0) {
            FeatureEnableSettingsRow(store: store, key: "settings.clipboard.enabled",
                detail: "settings.clipboard.enabledDetail", icon: "doc.on.clipboard", keyPath: \.clipboardEnabled)
            options
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.45)
        }
    }

    private var options: some View {
        VStack(spacing: 0) {
            HistorySettingsSection(store: store, clear: clearHistory, count: unpinnedHistoryCount)
            PrivacySettingsSection(store: store, actions: actions)
            ShortcutsSettingsSection(store: store, actions: actions)
        }
    }
}

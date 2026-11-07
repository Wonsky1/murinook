import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct FeatureEnableSettingsRow: View {
    let store: PreferencesStore
    let key: String
    let detail: String
    let icon: String
    let keyPath: WritableKeyPath<AppPreferences, Bool>

    var body: some View {
        SettingsRow(key: key, detail: detail, icon: icon) {
            Toggle(isOn: Binding(get: { store.value[keyPath: keyPath] },
                                 set: { enabled in store.update { $0[keyPath: keyPath] = enabled } })) {
                Text(LocalizedStringKey(key), bundle: .module)
            }
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(MurinookPalette.accent)
            .accessibilityLabel(Text(LocalizedStringKey(key), bundle: .module))
        }
    }
}

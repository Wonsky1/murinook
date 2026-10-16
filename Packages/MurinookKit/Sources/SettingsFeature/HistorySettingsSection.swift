import AppKit
import ApplicationServices
import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct HistorySettingsSection: View {
    let store: PreferencesStore; let clear: () -> Void; let count: () -> Int
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(key: "settings.capture", detail: "settings.captureDetail", icon: "clipboard") {
                Toggle(isOn: bind(\.captureEnabled)) { Text("settings.capture", bundle: .module) }.labelsHidden()
            }
            SettingsGroup(key: "settings.retention", detail: "settings.retentionDetail", icon: "calendar") {
                Picker(selection: bind(\.retentionDays)) {
                    Text("retention.7", bundle: .module).tag(7); Text("retention.30", bundle: .module).tag(30)
                    Text("retention.90", bundle: .module).tag(90); Text("retention.never", bundle: .module).tag(0)
                } label: { Text("settings.days", bundle: .module) }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsGroup(key: "settings.maxHistory", detail: "settings.maxHistoryDetail", icon: "list.number") {
                HStack(spacing: 8) {
                    TextField(value: bind(\.maxHistoryItems), format: .number) { Text("settings.maxHistory", bundle: .module) }
                        .textFieldStyle(.roundedBorder).frame(width: 110)
                        .accessibilityLabel(Text("settings.maxHistory", bundle: .module))
                    Stepper(value: bind(\.maxHistoryItems), in: 1...100_000, step: 500) { Text("settings.maxHistory", bundle: .module) }
                        .labelsHidden()
                    Spacer()
                }
            }
            SettingsGroup(key: "settings.clearHistory", detail: "settings.clearHistory.detail", icon: "trash") {
                Button(role: .destructive, action: clear) { Label { Text("settings.clearHistory.button", bundle: .module) } icon: { Image(systemName: "trash") } }
                    .buttonStyle(.bordered).disabled(count() == 0)
            }
        }
    }
    private func bind<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
        Binding(get: { store.value[keyPath: keyPath] }, set: { value in store.update { $0[keyPath: keyPath] = value } })
    }
}

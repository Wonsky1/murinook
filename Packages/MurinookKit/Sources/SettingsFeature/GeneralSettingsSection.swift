import AppKit
import ApplicationServices
import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct GeneralSettingsSection: View {
    let store: PreferencesStore; let actions: SettingsActions; let languageName: (String) -> String
    private var languageBinding: Binding<String> { Binding(get: { store.value.languageCode ?? "" }, set: { value in store.update { $0.languageCode = value.isEmpty ? nil : value } }) }
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(key: "settings.launchAtLogin", detail: "settings.launchAtLoginDetail", icon: "power") {
                HStack(spacing: 8) {
                    Toggle(isOn: Binding(get: { store.value.launchAtLogin }, set: { actions.setLaunchAtLogin($0) })) { Text("settings.launchAtLogin", bundle: .module) }.labelsHidden()
                    Button(action: actions.openLoginItemsSettings) { Text("settings.openLoginItems", bundle: .module) }.buttonStyle(.link).font(.system(size: 11))
                }
            }
            SettingsRow(key: "settings.dockIcon", detail: "settings.dockIconDetail", icon: "macwindow") {
                Toggle(isOn: Binding(get: { store.value.showsDockIcon }, set: { actions.setDockIconVisible($0) })) { Text("settings.dockIcon", bundle: .module) }.labelsHidden()
            }
            SettingsGroup(key: "settings.historyLayout", detail: "settings.historyLayoutDetail", icon: "rectangle.grid.2x2") {
                Picker(selection: Binding(get: { store.value.historyLayout }, set: { value in store.update { $0.historyLayout = value } })) {
                    Text("layout.grid", bundle: .module).tag(HistoryLayout.grid)
                    Text("layout.list", bundle: .module).tag(HistoryLayout.list)
                    Text("layout.strip", bundle: .module).tag(HistoryLayout.strip)
                } label: { Text("settings.historyLayout", bundle: .module) }.pickerStyle(.segmented).labelsHidden()
            }
            SettingsGroup(key: "settings.appearance", detail: "settings.appearanceDetail", icon: "sun.max") {
                Picker(selection: Binding(get: { store.value.appearance }, set: { value in store.update { $0.appearance = value } })) {
                    Text("appearance.system", bundle: .module).tag(AppAppearance.system)
                    Text("appearance.light", bundle: .module).tag(AppAppearance.light)
                    Text("appearance.dark", bundle: .module).tag(AppAppearance.dark)
                } label: { Text("settings.appearance", bundle: .module) }.pickerStyle(.segmented).labelsHidden()
            }
            SettingsGroup(key: "settings.language", detail: "settings.languageDetail", icon: "character.bubble") {
                Picker(selection: languageBinding) {
                    Text("language.system", bundle: .module).tag("")
                    ForEach(Bundle.module.localizations.filter { $0 != "Base" }.sorted(), id: \.self) { code in Text(languageName(code)).tag(code) }
                } label: { Text("settings.language", bundle: .module) }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

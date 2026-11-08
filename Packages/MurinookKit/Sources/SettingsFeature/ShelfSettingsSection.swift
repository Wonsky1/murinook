import AppKit
import ApplicationServices
import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct ShelfSettingsSection: View {
    let store: PreferencesStore
    let actions: SettingsActions
    var body: some View {
        VStack(spacing: 0) {
            FeatureEnableSettingsRow(store: store, key: "settings.shelf.enabled",
                detail: "settings.shelf.enabledDetail", icon: "tray", keyPath: \.shelfEnabled)
            VStack(spacing: 0) {
                options
                shelfShortcuts
            }
                .disabled(!store.value.shelfEnabled)
                .opacity(store.value.shelfEnabled ? 1 : 0.45)
        }
    }
    private var options: some View {
        VStack(spacing: 0) {
            SettingsRow(key: "settings.autoShowShelf", detail: "settings.autoShowShelfDetail", icon: "rectangle.trailinghalf.inset.filled") { Toggle(isOn: bind(\.autoShowShelf)) { Text("settings.autoShowShelf", bundle: .module) }.labelsHidden() }
            SettingsGroup(key: "settings.shelfPosition", detail: "settings.shelfPositionFreeDetail", icon: "move.3d") {
                SettingsRow(key: "settings.shelfPositionLock", detail: "settings.shelfPositionLockDetail", icon: "lock") {
                    Toggle(isOn: bind(\.shelfPositionLocked)) {
                        Text("settings.shelfPositionLock", bundle: .module)
                    }
                    .labelsHidden()
                    .accessibilityLabel(Text("settings.shelfPositionLock", bundle: .module))
                }
                if !store.value.shelfPositionLocked {
                    Button {
                        store.update { $0.shelfPosition = ShelfPosition(x: 1, y: 0.5) }
                    } label: {
                        Label {
                            Text("settings.resetShelfPosition", bundle: .module)
                        } icon: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(Text("settings.resetShelfPositionHelp", bundle: .module))
                }
            }
            SettingsRow(key: "settings.autoRemoveShelf", detail: "settings.autoRemoveShelfDetail", icon: "checkmark.circle") { Toggle(isOn: bind(\.autoRemoveShelfItems)) { Text("settings.autoRemoveShelf", bundle: .module) }.labelsHidden() }
        }
    }

    private var shelfShortcuts: some View {
        SettingsGroup(key: "settings.shelf.shortcuts", detail: "settings.shelf.shortcutsDetail", icon: "keyboard") {
            VStack(spacing: 0) {
                ShortcutSettingsRow(action: .shelf, store: store, actions: actions)
                Text("settings.shortcutHint", bundle: .module)
                    .font(.system(size: 11))
                    .foregroundStyle(MurinookPalette.soft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            }
        }
    }

    private func bind<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> { Binding(get: { store.value[keyPath: keyPath] }, set: { value in store.update { $0[keyPath: keyPath] = value } }) }
}

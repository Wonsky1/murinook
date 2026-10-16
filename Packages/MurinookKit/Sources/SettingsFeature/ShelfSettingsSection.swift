import AppKit
import ApplicationServices
import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct ShelfSettingsSection: View {
    let store: PreferencesStore
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(key: "settings.autoShowShelf", detail: "settings.autoShowShelfDetail", icon: "rectangle.trailinghalf.inset.filled") { Toggle(isOn: bind(\.autoShowShelf)) { Text("settings.autoShowShelf", bundle: .module) }.labelsHidden() }
            SettingsGroup(key: "settings.shelfSide", detail: "settings.shelfSideDetail", icon: "arrow.left.arrow.right") {
                Picker(selection: bind(\.shelfSide)) { Text("shelf.leftEdge", bundle: .module).tag(ShelfSide.left); Text("shelf.rightEdge", bundle: .module).tag(ShelfSide.right) } label: { Text("settings.shelfSide", bundle: .module) }.pickerStyle(.segmented).labelsHidden()
            }
            SettingsGroup(key: "settings.shelfPosition", detail: "settings.shelfPositionDetail", icon: "move.3d") { Slider(value: bind(\.shelfOffset), in: 0...1).accessibilityLabel(Text("settings.shelfPosition", bundle: .module)) }
            SettingsRow(key: "settings.autoRemoveShelf", detail: "settings.autoRemoveShelfDetail", icon: "checkmark.circle") { Toggle(isOn: bind(\.autoRemoveShelfItems)) { Text("settings.autoRemoveShelf", bundle: .module) }.labelsHidden() }
        }
    }
    private func bind<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> { Binding(get: { store.value[keyPath: keyPath] }, set: { value in store.update { $0[keyPath: keyPath] = value } }) }
}

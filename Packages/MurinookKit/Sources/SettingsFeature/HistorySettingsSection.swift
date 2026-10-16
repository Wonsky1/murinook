import AppKit
import ApplicationServices
import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct HistorySettingsSection: View {
    let store: PreferencesStore; let clear: () -> Void; let count: () -> Int
    @State private var confirmsUnlimited = false
    @State private var unlimitedChoice: UnlimitedLimit = .items
    @State private var lastFiniteItemLimit = 5_000

    private enum UnlimitedLimit { case time, items }

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(key: "settings.capture", detail: "settings.captureDetail", icon: "clipboard") {
                Toggle(isOn: bind(\.captureEnabled)) { Text("settings.capture", bundle: .module) }.labelsHidden()
            }
            SettingsGroup(key: "settings.retention", detail: "settings.retentionDetail", icon: "calendar") {
                Picker(selection: retention) {
                    Text("retention.7", bundle: .module).tag(7); Text("retention.30", bundle: .module).tag(30)
                    Text("retention.90", bundle: .module).tag(90); Text("retention.never", bundle: .module).tag(0)
                } label: { Text("settings.days", bundle: .module) }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsGroup(key: "settings.maxHistory", detail: "settings.maxHistoryDetail", icon: "list.number") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: unlimitedItems) { Text("settings.noItemLimit", bundle: .module) }
                        .toggleStyle(.switch).controlSize(.small)
                    if store.value.maxHistoryItems > 0 {
                        HStack(spacing: 8) {
                            TextField(value: finiteItems, format: .number) { Text("settings.maxHistory", bundle: .module) }
                                .textFieldStyle(.roundedBorder).frame(width: 110)
                                .accessibilityLabel(Text("settings.maxHistory", bundle: .module))
                            Stepper(value: finiteItems, in: 1...100_000, step: 500) { Text("settings.maxHistory", bundle: .module) }
                                .labelsHidden()
                            Spacer()
                        }
                    }
                }
            }
            if store.value.retentionDays == 0 || store.value.maxHistoryItems == 0 {
                Label {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("settings.unlimitedHistory.warningTitle", bundle: .module).font(.system(size: 12, weight: .semibold))
                        Text("settings.unlimitedHistory.warningMessage", bundle: .module)
                            .font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
                    }
                } icon: {
                    Image(systemName: "info.circle").foregroundStyle(MurinookPalette.accent)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(MurinookPalette.accentSoft.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                .padding(.vertical, 14)
            }
            SettingsGroup(key: "settings.clearHistory", detail: "settings.clearHistory.detail", icon: "trash") {
                Button(role: .destructive, action: clear) { Label { Text("settings.clearHistory.button", bundle: .module) } icon: { Image(systemName: "trash") } }
                    .buttonStyle(.bordered).disabled(count() == 0)
            }
        }
        .onAppear { rememberFiniteLimit(store.value.maxHistoryItems) }
        .onChange(of: store.value.maxHistoryItems) { _, value in rememberFiniteLimit(value) }
        .confirmationDialog(Text(unlimitedChoice == .time ? "settings.unlimitedTime.confirmTitle" : "settings.unlimitedItems.confirmTitle", bundle: .module),
                            isPresented: $confirmsUnlimited, titleVisibility: .visible) {
            Button { enableUnlimited() } label: { Text("settings.unlimitedHistory.confirm", bundle: .module) }
            Button(role: .cancel) {} label: { Text("settings.cancel", bundle: .module) }
        } message: {
            Text("settings.unlimitedHistory.warningMessage", bundle: .module)
        }
    }

    private var retention: Binding<Int> {
        Binding(get: { store.value.retentionDays }, set: { days in
            if days == 0 && store.value.retentionDays != 0 { requestUnlimited(.time) }
            else { store.update { $0.retentionDays = days } }
        })
    }

    private var unlimitedItems: Binding<Bool> {
        Binding(get: { store.value.maxHistoryItems == 0 }, set: { enabled in
            if enabled { requestUnlimited(.items) }
            else { store.update { $0.maxHistoryItems = lastFiniteItemLimit } }
        })
    }

    private var finiteItems: Binding<Int> {
        Binding(get: { store.value.maxHistoryItems }, set: { value in
            store.update { $0.maxHistoryItems = max(1, value) }
        })
    }

    private func rememberFiniteLimit(_ value: Int) {
        if value > 0 { lastFiniteItemLimit = value }
    }

    private func requestUnlimited(_ limit: UnlimitedLimit) {
        unlimitedChoice = limit
        confirmsUnlimited = true
    }

    private func enableUnlimited() {
        store.update {
            if unlimitedChoice == .time { $0.retentionDays = 0 }
            else { $0.maxHistoryItems = 0 }
        }
    }
    private func bind<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
        Binding(get: { store.value[keyPath: keyPath] }, set: { value in store.update { $0[keyPath: keyPath] = value } })
    }
}

import AppKit
import ApplicationServices
import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct PrivacySettingsSection: View {
    let store: PreferencesStore; let actions: SettingsActions
    @Environment(\.scenePhase) private var scenePhase
    @State private var permissionGranted = AXIsProcessTrusted()
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Image(systemName: "lock.shield.fill").foregroundStyle(MurinookPalette.accent)
                VStack(alignment: .leading, spacing: 3) { Text("settings.privacyTitle", bundle: .module).font(.system(size: 12, weight: .semibold)); Text("settings.privacyMessage", bundle: .module).font(.system(size: 11)).foregroundStyle(MurinookPalette.muted) }
                Spacer()
            }.padding(13).background(MurinookPalette.accentSoft, in: RoundedRectangle(cornerRadius: 12))
            SettingsGroup(key: "settings.excludedApps", detail: "settings.excludedAppsDetail", icon: "app.badge.checkmark") {
                ForEach(store.value.excludedBundleIDs, id: \.self) { id in
                    HStack(spacing: 9) {
                        Image(systemName: "app.fill").foregroundStyle(MurinookPalette.muted)
                        VStack(alignment: .leading, spacing: 2) { Text(id.components(separatedBy: ".").last ?? id); Text(id).font(.system(size: 11)).foregroundStyle(MurinookPalette.soft) }
                        Spacer()
                        Button { store.update { $0.excludedBundleIDs.removeAll { $0 == id } } } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain).accessibilityLabel(Text("settings.removeExcludedApp", bundle: .module))
                    }.padding(.vertical, 4)
                }
                Button(action: actions.chooseExcludedApps) { Label { Text("settings.addExcludedApp", bundle: .module) } icon: { Image(systemName: "plus") } }.buttonStyle(.bordered)
            }
            SettingsGroup(key: "settings.pastePermission", detail: "settings.pastePermissionDetail", icon: "accessibility") {
                HStack(spacing: 8) {
                    Circle().fill(permissionGranted ? MurinookPalette.accent : MurinookPalette.warm).frame(width: 7, height: 7)
                    Text(permissionGranted ? "settings.permissionGranted" : "settings.permissionMissing", bundle: .module).font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
                    Spacer(minLength: 0)
                    Button("settings.requestPastePermission", action: actions.requestPastePermission).buttonStyle(.borderedProminent)
                    Button("settings.accessibilityHelp", action: actions.showAccessibilityHelp).buttonStyle(.link)
                }
            }
        }
        .onAppear { permissionGranted = AXIsProcessTrusted() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { permissionGranted = AXIsProcessTrusted() } }
    }
}

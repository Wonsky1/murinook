import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct UpdateSettingsSection: View {
    let preferences: PreferencesStore
    let updates: UpdateStore?
    let currentVersion: String
    let actions: SettingsActions

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                MurinookBrandMark(size: 46)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Murinook").font(.system(size: 17, weight: .semibold))
                    Text(currentVersion).font(.system(size: 12, design: .monospaced)).foregroundStyle(MurinookPalette.muted)
                }
                Spacer()
            }.padding(.bottom, 24)
            SettingsRow(key: "settings.automaticUpdates", detail: "settings.automaticUpdatesDetail", icon: "arrow.triangle.2.circlepath") {
                Toggle(isOn: Binding(get: { preferences.value.automaticallyChecksForUpdates }, set: actions.setAutomaticUpdateChecks)) {
                    Text("settings.automaticUpdates", bundle: .module)
                }.labelsHidden()
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: statusSymbol).foregroundStyle(MurinookPalette.accent)
                    statusText.font(.system(size: 12)).foregroundStyle(MurinookPalette.text)
                    Spacer(minLength: 0)
                    if isChecking { ProgressView().controlSize(.small) }
                }
                HStack(spacing: 10) {
                    Button(action: actions.checkForUpdates) { Text("settings.checkForUpdates", bundle: .module) }
                        .buttonStyle(MurinookButtonStyle()).disabled(isChecking)
                    if case .available(let release) = updates?.state {
                        Button { actions.downloadUpdate(release) } label: { Text("settings.downloadUpdate", bundle: .module) }
                            .buttonStyle(MurinookButtonStyle(variant: .primary))
                        Button { actions.openUpdatePage(release) } label: { Text("settings.releaseNotes", bundle: .module) }
                            .buttonStyle(.link)
                    }
                }
                Text("settings.updateInstallHelp", bundle: .module)
                    .font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(.vertical, 18).frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
        }
    }

    private var isChecking: Bool { updates?.state == .checking }
    private var statusSymbol: String {
        switch updates?.state {
        case .available: "arrow.down.circle"
        case .failed: "wifi.exclamationmark"
        case .upToDate: "checkmark.circle"
        default: "arrow.triangle.2.circlepath"
        }
    }
    private var statusText: Text {
        switch updates?.state {
        case .checking: Text("settings.checkingUpdates", bundle: .module)
        case .available(let release):
            Text("settings.updateAvailable \(release.version.description)", bundle: .module)
        case .upToDate: Text("settings.noNewStableUpdate", bundle: .module)
        case .failed: Text("settings.updateCheckFailed", bundle: .module)
        default: Text("settings.updatesReady", bundle: .module)
        }
    }
}

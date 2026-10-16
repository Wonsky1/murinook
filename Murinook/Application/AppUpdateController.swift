import AppKit
import MurinookDomain
import MurinookUseCases

@MainActor
final class AppUpdateController {
    let store: UpdateStore
    let versionLabel: String
    private let preferences: PreferencesStore

    init(preferences: PreferencesStore, source: any ReleaseSource,
         currentVersion: ReleaseVersion, versionLabel: String) {
        self.preferences = preferences
        self.store = UpdateStore(source: source, currentVersion: currentVersion)
        self.versionLabel = versionLabel
    }

    func start() {
        guard preferences.value.automaticallyChecksForUpdates else { return }
        checkManually()
    }

    func checkManually() { Task { [store] in await store.check() } }
    func stop() { store.cancel() }

    func setAutomaticChecks(_ enabled: Bool) {
        guard preferences.update({ $0.automaticallyChecksForUpdates = enabled }) else { return }
        if enabled { start() } else { stop() }
    }

    func openPage(_ release: AppRelease) { NSWorkspace.shared.open(release.pageURL) }
    func download(_ release: AppRelease) { NSWorkspace.shared.open(release.downloadURL ?? release.pageURL) }
}

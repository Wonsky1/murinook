import MurinookUseCases
import MurinookStorage
import MurinookMacIntegration
import AppKit
import Foundation
import Observation
import MurinookDomain

@Observable final class ApplicationController {
    private(set) var isReady = false
    private(set) var startupProblem: String?
    let services: ApplicationServices
    let windows: ApplicationWindows
    let updates: AppUpdateController
    private let maintenance: ContentMaintenanceController
    private let visualBackfill: ContentVisualBackfill
    private let capture: ClipboardCaptureController
    private let effects: PreferencesEffectsController
    private let router: ContentActionRouter
    private let errors: ErrorPresenter
    private let defaults: UserDefaults

    init(directory: URL, defaults: UserDefaults = .standard) throws {
        self.defaults = defaults
        services = try ApplicationServices(directory: directory)
        let versionLabel = Bundle.main.object(forInfoDictionaryKey: "MurinookReleaseVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        guard let currentVersion = ReleaseVersion(versionLabel) else { throw CocoaError(.coderInvalidValue) }
        updates = AppUpdateController(preferences: services.preferences,
            source: GitHubReleaseSource(owner: "Wonsky1", repository: "murinook"),
            currentVersion: currentVersion, versionLabel: versionLabel)
        maintenance = ContentMaintenanceController(services: services)
        errors = ErrorPresenter(preferences: services.preferences, diagnostics: services.diagnostics)
        router = ContentActionRouter(services: services, errors: errors)
        effects = PreferencesEffectsController(services: services, errors: errors)
        let transfers = ShelfTransferController(services: services, errors: errors)
        transfers.requestCleanup = maintenance.request
        windows = ApplicationWindows(services: services, router: router, effects: effects, transfers: transfers,
            updates: updates, defaults: defaults)
        capture = ClipboardCaptureController(services: services)
        visualBackfill = ContentVisualBackfill(services: services)
        router.beforePaste = { [weak self] in self?.windows.quick.hide() }
        effects.onPlacement = { [weak self] in self?.windows.shelf.updatePlacement(side: $0, offset: $1) }
        effects.onLanguageChange = { [weak self] in self?.windows.updateLanguage($0) }
        effects.onShortcut = { [weak self] in self?.perform($0) }
        services.dragMonitor.onCandidate = { [weak self] _ in
            guard let self else { return }
            self.services.diagnostics.event("shelf.auto_show.policy", fields: ["enabled": String(self.services.preferences.value.autoShowShelf)])
            guard self.services.preferences.value.autoShowShelf else { return }
            self.windows.shelf.externalDragStarted()
        }
        services.dragMonitor.onDragEnded = { [weak self] in self?.windows.shelf.externalDragEnded() }
    }

    func start() async {
        services.diagnostics.event("application.start", fields: ["already_ready": String(isReady)])
        guard !isReady else { return }
        await services.history.load()
        await services.shelf.load()
        services.diagnostics.event("application.storage.loaded", fields: ["history_loaded": String(services.history.isLoaded),
            "shelf_loaded": String(services.shelf.isLoaded), "shelf_count": String(services.shelf.items.count)])
        guard services.history.isLoaded, services.shelf.isLoaded else {
            startupProblem = AppStrings.text("Could not open Murinook storage")
            return
        }
        await services.history.enforceRetention(now: .now)
        do {
            let retained = Set(services.history.clips.map(\.contentID) + services.shelf.items.map(\.contentID))
            try await services.storage.pruneUnreferencedContents(retaining: retained)
        } catch {
            errors.show("Could not clean old content", detail: error.localizedDescription)
        }
        if !defaults.bool(forKey: "shelfTransferRemovalEnabled") {
            services.preferences.update { $0.autoRemoveShelfItems = true }
            defaults.set(true, forKey: "shelfTransferRemovalEnabled")
        }
        maintenance.start()
        windows.start()
        effects.start()
        capture.start()
        visualBackfill.start()
        services.dragMonitor.start()
        startupProblem = nil
        isReady = true
        updates.start()
        services.diagnostics.event("application.ready", fields: ["auto_show_shelf": String(services.preferences.value.autoShowShelf)])
        windows.showLaunchExperience()
    }

    func stop() { windows.stop(); updates.stop(); router.stop(); maintenance.stop(); visualBackfill.stop(); capture.stop(); services.dragMonitor.stop(); services.bookmarks.releaseAllAccess() }

    func perform(_ action: ShortcutAction) {
        switch action {
        case .quickAccess: windows.showQuick()
        case .library: windows.showLibrary()
        case .shelf: windows.shelf.show()
        case .pasteNext:
            if let entry = services.queue.next { router.paste(entry.contentID, queueID: entry.id) }
        }
    }
}

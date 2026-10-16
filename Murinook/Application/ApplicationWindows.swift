import MurinookMacIntegration
import MurinookStorage
import AppKit
import Observation
import SwiftUI
import MurinookDomain
import MurinookUseCases
import MurinookPresentation
import ClipboardFeature
import ShelfFeature
import PasteQueueFeature
import SettingsFeature
import OnboardingFeature

final class ApplicationWindows {
    let quick = QuickAccessWindowController()
    let shelf = ShelfWindowController()
    let menuBarAnchor = MenuBarAnchor()
    private let services: ApplicationServices
    private let router: ContentActionRouter
    private let effects: PreferencesEffectsController
    private let transfers: ShelfTransferController
    private let updates: AppUpdateController
    private let defaults: UserDefaults
    private let foreground: WindowForegroundCoordinator
    private var presentation: ApplicationPresentationState
    private var library: FeatureWindowController?
    private var settings: FeatureWindowController?
    private let settingsNavigation = SettingsNavigation()
    private var queue: FeatureWindowController?
    private var onboarding: FeatureWindowController?
    private var backgroundExplanation: BackgroundExplanationController?

    init(services: ApplicationServices, router: ContentActionRouter,
         effects: PreferencesEffectsController, transfers: ShelfTransferController, updates: AppUpdateController,
         defaults: UserDefaults) {
        self.services = services; self.router = router; self.effects = effects; self.transfers = transfers
        self.updates = updates
        self.defaults = defaults
        foreground = WindowForegroundCoordinator { phase, window in
            services.diagnostics.event("window.presentation.\(phase)", fields: [
                "window": window.title, "active": String(NSApp.isActive),
                "activation_policy": String(NSApp.activationPolicy().rawValue),
                "key": String(window.isKeyWindow), "visible": String(window.isVisible),
                "minimized": String(window.isMiniaturized), "active_space": String(window.isOnActiveSpace),
                "frame": NSStringFromRect(window.frame)])
        }
        self.presentation = ApplicationPresentationState(
            onboardingCompleted: defaults.bool(forKey: "onboardingCompleted"),
            backgroundExplanationAcknowledged: defaults.bool(forKey: "backgroundExplanationAcknowledged"))
    }

    func start() {
        let value = self.services.preferences.value
        self.shelf.configure(side: value.shelfSide, offset: value.shelfOffset, itemCount: self.services.shelf.items.count, preferences: self.services.preferences,
            diagnostics: self.services.diagnostics,
            acceptDrop: self.transfers.acceptNative, isDropEnabled: self.transfers.canAcceptDrop) { [unowned self] in
            AnyView(FeatureEnvironment(preferences: self.services.preferences) {
                ShelfView(store: self.services.shelf, actions: ShelfActions(
                        draggingItems: self.transfers.draggingItems,
                        dragStarted: self.transfers.dragStarted,
                        preview: { [weak self] in self?.router.preview($0.contentID) },
                        hide: self.shelf.hide, close: self.shelf.hide,
                        dragCompleted: { [weak self] item, success in self?.transfers.dragCompleted(item, succeeded: success) }),
                        placement: ShelfPlacement(side: self.services.preferences.value.shelfSide,
                            offset: self.services.preferences.value.shelfOffset), onPlacementChange: { [weak self] placement in
                                self?.services.preferences.update { $0.shelfSide = placement.side; $0.shelfOffset = placement.offset }
                            }, headerDragArea: AnyView(EdgeMoveHandle(
                                move: { [weak self] in self?.shelf.moveAnchor(to: $0) },
                                finish: { [weak self] in self?.shelf.finishMoving() }).frame(height: 29)), isDragging: self.shelf.isDragging)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            })
        }
        self.shelf.placementChanged = { [weak self] side, offset in
            self?.services.preferences.update { $0.shelfSide = side; $0.shelfOffset = offset }
        }
        self.transfers.dropped = { [weak self] count in self?.shelf.dropped(itemCount: count) }
        observeShelf()
    }

    private func observeShelf() {
        withObservationTracking { _ = self.services.shelf.items } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.transfers.itemsChanged()
                self.shelf.itemsChanged(count: self.services.shelf.items.count)
                self.observeShelf()
            }
        }
    }

    func showQuick() {
        self.quick.show(content: AnyView(FeatureEnvironment(preferences: self.services.preferences) {
            QuickAccessView(store: self.services.history, actions: QuickAccessActions(
                paste: { [weak self] in self?.router.paste($0.contentID) },
                copy: { [weak self] in self?.router.copy($0.contentID) },
                pastePlain: { [weak self] in self?.router.paste($0.contentID, plain: true) },
                addToShelf: self.addToShelf, addToQueue: self.router.addToQueue,
                openLibrary: self.showLibrary, openHistorySettings: self.showHistorySettings,
                close: self.quick.hide), preferences: self.services.preferences)
        }), title: localized("Quick access"))
    }

    func showLibrary() {
        if library == nil {
            library = FeatureWindowController(title: "Murinook", size: NSSize(width: 1120, height: 740),
                minimumSize: NSSize(width: 840, height: 600), content: AnyView(FeatureEnvironment(preferences: self.services.preferences) {
                    LibraryView(store: self.services.history, actions: LibraryActions(
                        copy: { [weak self] in self?.router.copy($0.contentID) },
                        paste: { [weak self] in self?.router.paste($0.contentID) },
                        pastePlain: { [weak self] in self?.router.paste($0.contentID, plain: true) },
                        addToShelf: self.addToShelf, addToQueue: self.router.addToQueue,
                        preview: { [weak self] in self?.router.preview($0.contentID) },
                        reveal: { [weak self] in self?.router.reveal($0.contentID) }, export: self.router.export,
                        loadContent: { [weak self] id in try? await self?.services.storage.contents.get(id) },
                        showShelf: self.shelf.show, showSettings: self.showSettings,
                        manageRetention: self.showHistorySettings,
                        showUpdates: self.showUpdateSettings,
                        close: { [weak self] in self?.library?.close() }), preferences: self.services.preferences,
                        updates: self.updates.store)
                }), foreground: foreground, autosaveName: "Murinook.Library", onClose: { [weak self] in self?.libraryClosed() })
        }
        library?.show()
    }

    func showQueue() {
        if queue == nil {
            queue = FeatureWindowController(title: localized("Paste queue"), size: NSSize(width: 590, height: 480),
                minimumSize: NSSize(width: 590, height: 470), content: AnyView(FeatureEnvironment(preferences: self.services.preferences) {
                    PasteQueueView(store: self.services.queue, actions: PasteQueueActions(
                        pasteNext: { [weak self] in self?.router.paste($0.contentID, queueID: $0.id) },
                        copy: { [weak self] in self?.router.copy($0.contentID) },
                        close: { [weak self] in self?.queue?.hide() },
                        pasteNextPlainText: { [weak self] in self?.router.paste($0.contentID, plain: true, queueID: $0.id) }),
                        pasteNextShortcut: self.services.preferences.value.shortcuts[.pasteNext].map(ShortcutDescriptionFormatter.string(for:)) ?? "—")
                }), foreground: foreground, autosaveName: "Murinook.Queue")
        }
        queue?.show()
    }

    func showSettings() {
        if settings == nil {
            settings = FeatureWindowController(title: localized("Settings"), size: NSSize(width: 920, height: 630),
                minimumSize: NSSize(width: 780, height: 560), content: settingsView, foreground: foreground, autosaveName: "Murinook.Settings")
        }
        settings?.show()
    }

    private func showHistorySettings() {
        settingsNavigation.selection = .history
        showSettings()
    }

    func showUpdateSettings() {
        settingsNavigation.selection = .updates
        showSettings()
    }

    var settingsView: AnyView {
        AnyView(FeatureEnvironment(preferences: self.services.preferences) {
            SettingsFeature.SettingsView(store: self.services.preferences, actions: SettingsActions(
                chooseExcludedApps: self.effects.chooseExcludedApps, recordShortcut: self.effects.record,
                resetShortcut: self.effects.resetShortcut, disableShortcut: self.effects.disableShortcut,
                showAccessibilityHelp: self.effects.openAccessibilitySettings,
                requestPastePermission: self.services.permission.requestAccessibilityPrompt,
                openLoginItemsSettings: self.effects.openLoginSettings,
                setDockIconVisible: self.effects.setDockVisible, setLaunchAtLogin: self.effects.setLaunchAtLogin,
                clearUnpinnedHistory: { Task { await self.services.history.clearUnpinned() } },
                unpinnedHistoryCount: { self.services.history.clips.filter { !$0.isPinned }.count },
                checkForUpdates: self.updates.checkManually,
                setAutomaticUpdateChecks: self.updates.setAutomaticChecks,
                openUpdatePage: self.updates.openPage, downloadUpdate: self.updates.download,
                shortcutDescription: { $0.map(ShortcutDescriptionFormatter.string(for:)) ?? "—" }),
                navigation: self.settingsNavigation, updates: self.updates.store, currentVersion: self.updates.versionLabel)
        })
    }

    func showOnboarding() {
        if let onboarding { onboarding.show(); return }
        onboarding = FeatureWindowController(title: "Murinook", size: NSSize(width: 760, height: 550),
            minimumSize: NSSize(width: 760, height: 550), content: AnyView(FeatureEnvironment(preferences: self.services.preferences) {
                OnboardingView(store: self.services.preferences, actions: OnboardingActions(
                    requestPastePermission: self.services.permission.requestAccessibilityPrompt,
                    openAccessibilitySettings: self.effects.openAccessibilitySettings,
                    finish: { [weak self] in self?.finishOnboarding() }))
            }), foreground: foreground, onClose: { [weak self] in self?.finishOnboarding() })
        onboarding?.show()
    }

    func showLaunchExperience() {
        let needsOnboarding = presentation.launch()
        showLibrary()
        if needsOnboarding { showOnboarding() }
    }

    func reopen() {
        showLibrary()
        if presentation.onboardingVisible { showOnboarding() }
    }

    func stop() {
        presentation.terminate()
        foreground.cancelAll()
        backgroundExplanation?.stop()
    }

    private func finishOnboarding() {
        presentation.completeOnboarding()
        defaults.set(true, forKey: "onboardingCompleted")
        onboarding?.hide()
        showLibrary()
    }

    private func libraryClosed() {
        guard presentation.libraryClosed() else { return }
        if backgroundExplanation == nil {
            backgroundExplanation = BackgroundExplanationController(anchor: menuBarAnchor,
                onDismiss: { [weak self] in self?.acknowledgeBackgroundExplanation() })
        }
        backgroundExplanation?.show(content: AnyView(FeatureEnvironment(preferences: services.preferences) {
            BackgroundRunningView(dismiss: { [weak self] in self?.backgroundExplanation?.dismiss() })
        }))
    }

    private func acknowledgeBackgroundExplanation() {
        presentation.dismissBackgroundExplanation()
        defaults.set(true, forKey: "backgroundExplanationAcknowledged")
    }

    func updateLanguage(_ locale: Locale) {
        settings?.setTitle(AppStrings.text("Settings", locale: locale))
        queue?.setTitle(AppStrings.text("Paste queue", locale: locale))
        quick.setTitle(AppStrings.text("Quick access", locale: locale))
    }

    private func addToShelf(_ clip: Clip) { self.router.addToShelf(clip); self.shelf.show() }
    private func localized(_ key: String) -> String {
        AppStrings.text(key, locale: self.services.preferences.value.languageCode.map(Locale.init(identifier:)) ?? .current)
    }
}

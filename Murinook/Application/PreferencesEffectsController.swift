import AppKit
import Observation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers
import MurinookDomain
import MurinookUseCases
import MurinookMacIntegration

final class PreferencesEffectsController {
    private let services: ApplicationServices
    private let errors: ErrorPresenter
    private let shortcuts: ShortcutSettingsController
    private var applied: AppPreferences?
    var onShortcut: ((ShortcutAction) -> Void)? {
        get { shortcuts.onShortcut }
        set { shortcuts.onShortcut = newValue }
    }
    var onLanguageChange: ((Locale) -> Void)?
    var onPlacement: ((ShelfSide, Double) -> Void)?

    init(services: ApplicationServices, errors: ErrorPresenter) {
        self.services = services; self.errors = errors
        self.shortcuts = ShortcutSettingsController(preferences: services.preferences, errors: errors)
    }

    func start() { apply(); observe() }

    private func observe() {
        withObservationTracking {
            _ = services.preferences.value
        } onChange: { [weak self] in
            Task { @MainActor in self?.apply(); self?.observe() }
        }
    }

    private func apply() {
        let value = services.preferences.value
        services.monitor.update(policy: ClipboardCapturePolicy(isEnabled: value.captureEnabled,
            excludedBundleIdentifiers: Set(value.excludedBundleIDs)))
        if applied?.showsDockIcon != value.showsDockIcon {
            NSApp.setActivationPolicy(value.showsDockIcon ? .regular : .accessory)
        }
        shortcuts.synchronize()
        if applied?.appearance != value.appearance {
            switch value.appearance {
            case .system: NSApp.appearance = nil
            case .light: NSApp.appearance = NSAppearance(named: .aqua)
            case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
        if applied == nil || applied?.languageCode != value.languageCode {
            onLanguageChange?(value.languageCode.map(Locale.init(identifier:)) ?? .current)
        }
        onPlacement?(value.shelfSide, value.shelfOffset)
        applied = value
    }

    func chooseExcludedApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(filePath: "/Applications", directoryHint: .isDirectory)
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in
                guard let self else { return }
                let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
                self.services.preferences.update { value in
                    value.excludedBundleIDs = Array(Set(value.excludedBundleIDs).union(ids)).sorted()
                }
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            services.preferences.update { $0.launchAtLogin = enabled }
            if SMAppService.mainApp.status == .requiresApproval { openLoginSettings() }
        } catch { errors.show("Could not change launch at login", detail: error.localizedDescription) }
    }

    func setDockVisible(_ visible: Bool) { services.preferences.update { $0.showsDockIcon = visible } }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    func record(_ action: ShortcutAction) { shortcuts.record(action) }
    func resetShortcut(_ action: ShortcutAction) { shortcuts.reset(action) }
    func disableShortcut(_ action: ShortcutAction) { shortcuts.disable(action) }
}

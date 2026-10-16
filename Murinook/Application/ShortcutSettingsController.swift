import AppKit
import MurinookDomain
import MurinookMacIntegration
import MurinookUseCases

/// Coordinates editing with the saved preferences and the currently active system-wide bindings.
@MainActor
final class ShortcutSettingsController {
    private let preferences: PreferencesStore
    private let errors: ErrorPresenter
    private let hotkeys = CarbonHotKeyRegistrar()
    private var registrations: [HotKeyRegistration] = []
    private var activeBindings: [ShortcutAction: KeyCombination]?
    private var recordingWindow: ShortcutRecordingWindowController?
    var onShortcut: ((ShortcutAction) -> Void)?

    init(preferences: PreferencesStore, errors: ErrorPresenter) {
        self.preferences = preferences
        self.errors = errors
    }

    func synchronize() {
        guard recordingWindow == nil, activeBindings != preferences.value.shortcuts else { return }
        do { try activate(preferences.value.shortcuts) }
        catch { errors.show("Could not register keyboard shortcut", detail: message(for: error)) }
    }

    func record(_ action: ShortcutAction) {
        recordingWindow?.close()
        // Temporarily free our own bindings so re-recording a currently assigned chord works.
        hotkeys.unregisterAll()
        registrations = []
        activeBindings = nil
        let window = ShortcutRecordingWindowController(action: action,
            current: preferences.value.shortcuts[action], locale: locale,
            save: { [weak self] combination in self?.save(combination, for: action) },
            didClose: { [weak self] in
                self?.recordingWindow = nil
                self?.synchronize()
            })
        recordingWindow = window
        window.show()
    }

    func reset(_ action: ShortcutAction) { set(KeyCombination.defaults[action], for: action) }
    func disable(_ action: ShortcutAction) { set(nil, for: action) }

    private func set(_ combination: KeyCombination?, for action: ShortcutAction) {
        recordingWindow?.close()
        if let failure = save(combination, for: action) {
            errors.show("Could not register keyboard shortcut", detail: failure)
        }
    }

    /// Returns a localized error without persisting a binding that macOS could not register.
    private func save(_ combination: KeyCombination?, for action: ShortcutAction) -> String? {
        let previous = preferences.value.shortcuts
        if let combination, let existing = ShortcutAction.allCases.first(where: {
            $0 != action && previous[$0] == combination
        }) {
            return message(for: HotKeyRegistrationError.duplicate(action: existing))
        }
        var candidate = previous
        candidate[action] = combination
        do { try activate(candidate) }
        catch { return message(for: error) }

        guard preferences.update({ $0.shortcuts = candidate }) else {
            // Remove the unsaved candidate first: even a failed restore must never resurrect it.
            hotkeys.unregisterAll()
            registrations = []
            activeBindings = nil
            if recordingWindow == nil {
                do { try activate(previous) }
                catch { errors.show("Could not register keyboard shortcut", detail: message(for: error)) }
            }
            return localized("Could not save this shortcut. Your previous shortcut is unchanged.")
        }
        return nil
    }

    private func activate(_ bindings: [ShortcutAction: KeyCombination]) throws {
        do {
            registrations = try hotkeys.register(bindings) { [weak self] action in
                guard let self, recordingWindow == nil else { return }
                onShortcut?(action)
            }
            activeBindings = bindings
        } catch {
            if case HotKeyRegistrationError.restorationFailed = error {
                registrations = []
                activeBindings = nil
            }
            throw error
        }
    }

    private func message(for error: Error) -> String {
        guard let registration = error as? HotKeyRegistrationError else {
            return localized("This shortcut could not be registered. Try another key or combination.")
        }
        switch registration {
        case .duplicate(let action):
            return String(format: localized("This shortcut is already assigned to %@."), localized("shortcut." + action.rawValue))
        case .invalidCombination:
            return localized("Choose a key or key combination, rather than a modifier alone.")
        case .registration:
            return localized("This shortcut is unavailable or used by macOS or another app. Try another combination.")
        case .eventHandler:
            return localized("Keyboard shortcuts could not start. Please try again.")
        case .restorationFailed:
            return localized("Previous shortcuts could not be restored. Please try again.")
        }
    }

    private var locale: Locale { preferences.value.languageCode.map(Locale.init(identifier:)) ?? .current }
    private func localized(_ key: String) -> String { AppStrings.text(key, locale: locale) }
}

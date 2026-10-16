import MurinookDomain
import AppKit
import MurinookUseCases
import MurinookMacIntegration

final class ErrorPresenter {
    private let preferences: PreferencesStore
    private let diagnostics: DragDiagnostics?
    init(preferences: PreferencesStore, diagnostics: DragDiagnostics? = nil) {
        self.preferences = preferences
        self.diagnostics = diagnostics
    }

    func show(_ key: String, detail: String? = nil) {
        diagnostics?.event("ui.error.presented", fields: ["message_key": key, "has_detail": String(detail != nil)])
        let locale = preferences.value.languageCode.map(Locale.init(identifier:)) ?? .current
        let alert = NSAlert()
        alert.messageText = AppStrings.text(key, locale: locale)
        alert.informativeText = detail ?? ""
        alert.addButton(withTitle: AppStrings.text("OK", locale: locale))
        alert.alertStyle = .warning
        NSApp.activate()
        alert.runModal()
        diagnostics?.event("ui.error.dismissed", fields: ["message_key": key])
    }
}

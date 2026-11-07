import MurinookDomain
import MurinookUseCases
import MurinookWindowManagement
import Foundation

/// Routes native window commands without coupling them to clipboard or shelf storage.
@MainActor
final class WindowActionsController {
    private let manager: WindowManager
    private let preferences: PreferencesStore
    private let errors: ErrorPresenter
    private let notice: WindowPlacementNotice

    init(manager: WindowManager, preferences: PreferencesStore, errors: ErrorPresenter, notice: WindowPlacementNotice) {
        self.manager = manager
        self.preferences = preferences
        self.errors = errors
        self.notice = notice
    }

    func perform(_ action: WindowAction) {
        guard preferences.value.windowManagementEnabled else { return }
        notice.hide()
        do {
            if case .sizeConstrained(let frame) = try manager.execute(action) {
                let locale = preferences.value.languageCode.map(Locale.init(identifier:)) ?? .current
                notice.show(message: AppStrings.text("window.notice.minimumSize", locale: locale), windowFrame: frame)
            }
        }
        catch let error as WindowManagementError {
            if error == .accessibilityRequired { _ = manager.requestAccessibilityAccess() }
            errors.show(messageKey(for: error))
        } catch { errors.show("window.error.operationFailed") }
    }

    func stop() { notice.hide() }

    private func messageKey(for error: WindowManagementError) -> String {
        switch error {
        case .accessibilityRequired: "window.error.accessibilityRequired"
        case .noWindow: "window.error.noWindow"
        case .unsupportedWindow: "window.error.unsupportedWindow"
        case .noOtherDisplay: "window.error.noOtherDisplay"
        case .noRestoreFrame: "window.error.noRestoreFrame"
        case .operationFailed: "window.error.operationFailed"
        }
    }
}

import MurinookDomain
import MurinookUseCases
import MurinookWindowManagement

/// Routes native window commands without coupling them to clipboard or shelf storage.
@MainActor
final class WindowActionsController {
    private let manager: WindowManager
    private let preferences: PreferencesStore
    private let errors: ErrorPresenter

    init(manager: WindowManager, preferences: PreferencesStore, errors: ErrorPresenter) {
        self.manager = manager
        self.preferences = preferences
        self.errors = errors
    }

    func perform(_ action: WindowAction) {
        guard preferences.value.windowManagementEnabled else { return }
        do { try manager.execute(action) }
        catch let error as WindowManagementError {
            if error == .accessibilityRequired { _ = manager.requestAccessibilityAccess() }
            errors.show(messageKey(for: error))
        } catch { errors.show("window.error.operationFailed") }
    }

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

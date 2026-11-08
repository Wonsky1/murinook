import AppKit
import MurinookPresentation

/// Keeps one owner for the application's activation policy.
@MainActor
final class DockPresenceController {
    private var state = DockPresenceState()
    private let onPolicyChange: (Bool, Bool) -> Void

    init(onPolicyChange: @escaping (Bool, Bool) -> Void = { _, _ in }) {
        self.onPolicyChange = onPolicyChange
    }

    func setAlwaysShow(_ enabled: Bool) {
        state.alwaysShowIcon = enabled
        apply()
    }

    func setOpen(_ isOpen: Bool, for window: DockPresenceState.Window) {
        state.setOpen(isOpen, for: window)
        apply()
    }

    private func apply() {
        let policy: NSApplication.ActivationPolicy = state.shouldShowIcon ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        let accepted = NSApp.setActivationPolicy(policy)
        onPolicyChange(state.shouldShowIcon, accepted && NSApp.activationPolicy() == policy)
    }
}

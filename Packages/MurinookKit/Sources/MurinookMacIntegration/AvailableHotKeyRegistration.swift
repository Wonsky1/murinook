import Carbon
import MurinookDomain

@MainActor
public struct HotKeyRegistrationBatch {
    public let registrations: [HotKeyRegistration]
    public let unavailableWindowActions: Set<ShortcutAction>
}

public extension CarbonHotKeyRegistrar {
    /// Window presets must not prevent unrelated app shortcuts from registering.
    /// An explicitly edited binding remains strict so the recorder can report its conflict.
    func registerAvailable(_ combinations: [ShortcutAction: KeyCombination],
                           requiredAction: ShortcutAction? = nil,
                           onAction: @escaping @MainActor (ShortcutAction) -> Void) throws -> HotKeyRegistrationBatch {
        var remaining = combinations
        var unavailable: Set<ShortcutAction> = []
        while true {
            do {
                let registrations = try register(remaining, onAction: onAction)
                return HotKeyRegistrationBatch(registrations: registrations, unavailableWindowActions: unavailable)
            } catch let error as HotKeyRegistrationError {
                guard case .registration(let name, let status) = error,
                      status == OSStatus(eventHotKeyExistsErr),
                      let action = ShortcutAction(rawValue: name), action.windowAction != nil,
                      action != requiredAction, remaining.removeValue(forKey: action) != nil else { throw error }
                // register() restored the previous registrations. Retry the reduced
                // set; every iteration removes one window binding, so this is bounded.
                unavailable.insert(action)
            }
        }
    }
}

import AppKit
import Carbon
import Foundation
import MurinookDomain

public enum HotKeyRegistrationError: Error, LocalizedError, Sendable {
    case eventHandler(OSStatus)
    case registration(action: String, status: OSStatus)
    case duplicate(action: ShortcutAction)
    case invalidCombination
    case restorationFailed

    public var errorDescription: String? {
        switch self {
        case .eventHandler(let status): "Global shortcut event handling could not start (\(status))."
        case .registration(let action, let status): "The shortcut for \(action) could not be registered (\(status))."
        case .duplicate(let action): "The shortcut for \(action) is already assigned to another action."
        case .invalidCombination: "The shortcut contains an unsupported key or modifier."
        case .restorationFailed: "The previous global shortcuts could not be restored after the replacement failed."
        }
    }
}

@MainActor
public final class HotKeyRegistration {
    private weak var registrar: CarbonHotKeyRegistrar?
    private let action: ShortcutAction
    private let identifier: UInt32

    fileprivate init(registrar: CarbonHotKeyRegistrar, action: ShortcutAction, identifier: UInt32) {
        self.registrar = registrar
        self.action = action
        self.identifier = identifier
    }

    public func cancel() {
        registrar?.unregister(action: action, identifier: identifier)
        registrar = nil
    }
}

/// Registers customizable system-wide shortcuts through Carbon's native hot-key API.
@MainActor
public final class CarbonHotKeyRegistrar {
    private struct Entry {
        let reference: EventHotKeyRef
        let action: ShortcutAction
        let identifier: UInt32
    }

    private var handler: EventHandlerRef?
    private var context: Unmanaged<CarbonHotKeyRegistrar>?
    private var entries: [ShortcutAction: Entry] = [:]
    private var combinations: [ShortcutAction: KeyCombination] = [:]
    private var callbacks: [ShortcutAction: @MainActor () -> Void] = [:]
    private var nextIdentifier: UInt32 = 1

    public init() {}

    @discardableResult
    public func register(
        _ newCombinations: [ShortcutAction: KeyCombination],
        onAction: @escaping @MainActor (ShortcutAction) -> Void
    ) throws -> [HotKeyRegistration] {
        try validate(newCombinations)

        let previousCombinations = combinations
        let previousCallbacks = callbacks
        let previousIdentifiers = entries.mapValues(\.identifier)

        for action in Array(entries.keys) {
            if let entry = entries.removeValue(forKey: action) {
                UnregisterEventHotKey(entry.reference)
            }
        }
        combinations.removeAll()
        callbacks.removeAll()

        do {
            var newIdentifiers: [ShortcutAction: UInt32] = [:]
            for (action, combination) in newCombinations.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                let identifier = allocateIdentifier()
                try install(action: action, combination: combination, identifier: identifier)
                combinations[action] = combination
                callbacks[action] = { @MainActor in onAction(action) }
                newIdentifiers[action] = identifier
            }
            removeHandlerIfIdle()
            return newIdentifiers.map { HotKeyRegistration(registrar: self, action: $0.key, identifier: $0.value) }
        } catch let registrationError {
            for action in Array(entries.keys) {
                if let entry = entries.removeValue(forKey: action) {
                    UnregisterEventHotKey(entry.reference)
                }
            }
            combinations.removeAll()
            callbacks.removeAll()

            do {
                for (action, combination) in previousCombinations.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                    guard let identifier = previousIdentifiers[action] else { continue }
                    try install(action: action, combination: combination, identifier: identifier)
                    combinations[action] = combination
                }
                callbacks = previousCallbacks
            } catch {
                unregisterAll()
                throw HotKeyRegistrationError.restorationFailed
            }
            throw registrationError
        }
    }

    public func unregisterAll() {
        for action in Array(entries.keys) {
            if let entry = entries.removeValue(forKey: action) { UnregisterEventHotKey(entry.reference) }
        }
        combinations.removeAll()
        callbacks.removeAll()
        removeHandlerIfIdle()
    }

    fileprivate func unregister(action: ShortcutAction, identifier: UInt32) {
        guard entries[action]?.identifier == identifier else { return }
        if let entry = entries.removeValue(forKey: action) { UnregisterEventHotKey(entry.reference) }
        combinations.removeValue(forKey: action)
        callbacks.removeValue(forKey: action)
        removeHandlerIfIdle()
    }

    fileprivate func receive(identifier: UInt32) {
        guard let action = entries.values.first(where: { $0.identifier == identifier })?.action else { return }
        callbacks[action]?()
    }

    private func validate(_ combinations: [ShortcutAction: KeyCombination]) throws {
        let validModifierMask: UInt32 = ShortcutModifiers.command.rawValue
            | ShortcutModifiers.option.rawValue
            | ShortcutModifiers.control.rawValue
            | ShortcutModifiers.shift.rawValue
        var seen: Set<KeyCombination> = []
        for (action, combination) in combinations.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            guard combination.keyCode <= 127,
                  !Self.modifierKeyCodes.contains(combination.keyCode),
                  combination.modifiers.rawValue & ~validModifierMask == 0 else {
                throw HotKeyRegistrationError.invalidCombination
            }
            guard seen.insert(combination).inserted else {
                throw HotKeyRegistrationError.duplicate(action: action)
            }
        }
    }

    private func install(action: ShortcutAction, combination: KeyCombination, identifier: UInt32) throws {
        try ensureHandler()
        let hotKeyID = EventHotKeyID(signature: fourCharCode("MURI"), id: identifier)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combination.keyCode,
            carbonModifiers(combination.modifiers),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            throw HotKeyRegistrationError.registration(action: String(describing: action), status: status)
        }
        entries[action] = Entry(reference: reference, action: action, identifier: identifier)
    }

    private func allocateIdentifier() -> UInt32 {
        let identifier = nextIdentifier
        nextIdentifier &+= 1
        if nextIdentifier == 0 { nextIdentifier = 1 }
        return identifier
    }

    private func ensureHandler() throws {
        guard handler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        context = Unmanaged.passUnretained(self)
        let status = InstallEventHandler(GetEventDispatcherTarget(), murinookHotKeyEventHandler, 1, &eventType, context!.toOpaque(), &handler)
        guard status == noErr else { context = nil; throw HotKeyRegistrationError.eventHandler(status) }
    }

    private func removeHandlerIfIdle() {
        guard entries.isEmpty, let handler else { return }
        RemoveEventHandler(handler)
        self.handler = nil
        context = nil
    }

    private func carbonModifiers(_ modifiers: ShortcutModifiers) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) | OSType($1) }
    }

    private static let modifierKeyCodes: Set<UInt32> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
}

private func murinookHotKeyEventHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    guard status == noErr else { return status }
    let registrar = Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in registrar.receive(identifier: hotKeyID.id) }
    return noErr
}

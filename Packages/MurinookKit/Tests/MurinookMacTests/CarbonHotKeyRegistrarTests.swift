import XCTest
import MurinookDomain
@testable import MurinookMacIntegration

@MainActor
final class CarbonHotKeyRegistrarTests: XCTestCase {
    func testRegistersBareF18AndReturnsCancelableRegistration() throws {
        let registrar = CarbonHotKeyRegistrar()
        var fired = false

        let tokens = try registrar.register([.quickAccess: KeyCombination(keyCode: 0x4F, modifiers: [])]) { _ in fired = true }
        defer { tokens.forEach { $0.cancel() } }

        XCTAssertEqual(tokens.count, 1)
        XCTAssertFalse(fired)
    }

    func testRejectsDuplicateCombinationsBeforeChangingExistingRegistration() throws {
        let registrar = CarbonHotKeyRegistrar()
        _ = try registrar.register([.quickAccess: KeyCombination(keyCode: 0x4F, modifiers: [])]) { _ in }
        defer { registrar.unregisterAll() }

        XCTAssertThrowsError(try registrar.register([
            .quickAccess: KeyCombination(keyCode: 0x4F, modifiers: []),
            .library: KeyCombination(keyCode: 0x4F, modifiers: [])
        ]) { _ in }) { error in
            guard case HotKeyRegistrationError.duplicate(action: .quickAccess) = error else {
                return XCTFail("Expected duplicate shortcut error, got \(error)")
            }
        }

        let contender = CarbonHotKeyRegistrar()
        defer { contender.unregisterAll() }
        XCTAssertThrowsError(try contender.register([.shelf: KeyCombination(keyCode: 0x4F, modifiers: [])]) { _ in })
    }

    func testRejectsInvalidKeyCodeAndModifierBitsWithoutReplacingCurrentRegistration() throws {
        let registrar = CarbonHotKeyRegistrar()
        _ = try registrar.register([.quickAccess: KeyCombination(keyCode: 0x4F, modifiers: [])]) { _ in }
        defer { registrar.unregisterAll() }

        for keyCode: UInt32 in [55, 128] {
            XCTAssertThrowsError(try registrar.register([.library: KeyCombination(keyCode: keyCode, modifiers: [])]) { _ in }) { error in
                guard case HotKeyRegistrationError.invalidCombination = error else {
                    return XCTFail("Expected invalid shortcut error, got \(error)")
                }
            }
        }

        let contender = CarbonHotKeyRegistrar()
        defer { contender.unregisterAll() }
        XCTAssertThrowsError(try contender.register([.shelf: KeyCombination(keyCode: 0x4F, modifiers: [])]) { _ in })
    }

    func testReplacementFailureRestoresPreviousShortcut() throws {
        let registrar = CarbonHotKeyRegistrar()
        _ = try registrar.register([.quickAccess: KeyCombination(keyCode: 0x4F, modifiers: [])]) { _ in }
        defer { registrar.unregisterAll() }

        let blocker = CarbonHotKeyRegistrar()
        _ = try blocker.register([.library: KeyCombination(keyCode: 0x4D, modifiers: [])]) { _ in }
        defer { blocker.unregisterAll() }

        XCTAssertThrowsError(try registrar.register([.pasteNext: KeyCombination(keyCode: 0x4D, modifiers: [])]) { _ in })

        let probe = CarbonHotKeyRegistrar()
        defer { probe.unregisterAll() }
        XCTAssertThrowsError(try probe.register([.shelf: KeyCombination(keyCode: 0x4F, modifiers: [])]) { _ in })
    }

    func testOldTokenStillCancelsRegistrationRestoredAfterFailedReplacement() throws {
        let registrar = CarbonHotKeyRegistrar()
        let oldTokens = try registrar.register([.quickAccess: KeyCombination(keyCode: 0x4F, modifiers: [])]) { _ in }
        defer { registrar.unregisterAll() }

        let blocker = CarbonHotKeyRegistrar()
        _ = try blocker.register([.library: KeyCombination(keyCode: 0x4D, modifiers: [])]) { _ in }
        defer { blocker.unregisterAll() }

        XCTAssertThrowsError(try registrar.register([.pasteNext: KeyCombination(keyCode: 0x4D, modifiers: [])]) { _ in })

        oldTokens.forEach { $0.cancel() }

        let probe = CarbonHotKeyRegistrar()
        defer { probe.unregisterAll() }
        XCTAssertNoThrow(try probe.register([.shelf: KeyCombination(keyCode: 0x4F, modifiers: [])]) { _ in })
    }

    func testStaleTokenCannotRemoveNewerRegistrationForSameAction() throws {
        let registrar = CarbonHotKeyRegistrar()
        let old = try registrar.register([.quickAccess: KeyCombination(keyCode: 0x4F, modifiers: [])]) { _ in }
        _ = try registrar.register([.quickAccess: KeyCombination(keyCode: 0x4D, modifiers: [])]) { _ in }
        defer { registrar.unregisterAll() }

        old.forEach { $0.cancel() }

        let probe = CarbonHotKeyRegistrar()
        defer { probe.unregisterAll() }
        XCTAssertThrowsError(try probe.register([.shelf: KeyCombination(keyCode: 0x4D, modifiers: [])]) { _ in })
    }
}

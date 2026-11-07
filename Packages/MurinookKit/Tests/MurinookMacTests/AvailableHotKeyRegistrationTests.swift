import XCTest
import MurinookDomain
@testable import MurinookMacIntegration

@MainActor
final class AvailableHotKeyRegistrationTests: XCTestCase {
    func testOccupiedWindowPresetDoesNotDisableAppOrOtherWindowShortcuts() throws {
        let blocker = CarbonHotKeyRegistrar()
        let registrar = CarbonHotKeyRegistrar()
        let probe = CarbonHotKeyRegistrar()
        defer { blocker.unregisterAll(); registrar.unregisterAll(); probe.unregisterAll() }
        let occupied = KeyCombination(keyCode: 0x4F, modifiers: [])
        let app = KeyCombination(keyCode: 0x50, modifiers: [])
        let otherWindow = KeyCombination(keyCode: 0x5A, modifiers: [])
        _ = try blocker.register([.shelf: occupied]) { _ in }

        let batch = try registrar.registerAvailable([
            .quickAccess: app, .windowLeftHalf: occupied, .windowRightHalf: otherWindow
        ]) { _ in }

        XCTAssertEqual(batch.unavailableWindowActions, [.windowLeftHalf])
        XCTAssertEqual(batch.registrations.count, 2)
        XCTAssertThrowsError(try probe.register([.library: app]) { _ in })
        XCTAssertThrowsError(try probe.register([.library: otherWindow]) { _ in })
    }

    func testExplicitlyEditedConflictRetainsPreviousRegistration() throws {
        let blocker = CarbonHotKeyRegistrar()
        let registrar = CarbonHotKeyRegistrar()
        let probe = CarbonHotKeyRegistrar()
        defer { blocker.unregisterAll(); registrar.unregisterAll(); probe.unregisterAll() }
        let occupied = KeyCombination(keyCode: 0x4F, modifiers: [])
        let app = KeyCombination(keyCode: 0x50, modifiers: [])
        _ = try blocker.register([.shelf: occupied]) { _ in }
        _ = try registrar.register([.quickAccess: app]) { _ in }

        XCTAssertThrowsError(try registrar.registerAvailable([
            .quickAccess: app, .windowLeftHalf: occupied
        ], requiredAction: .windowLeftHalf) { _ in })
        XCTAssertThrowsError(try probe.register([.library: app]) { _ in })
    }
}

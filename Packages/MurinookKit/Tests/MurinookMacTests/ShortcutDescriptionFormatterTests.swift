import XCTest
import MurinookDomain
@testable import MurinookMacIntegration

@MainActor
final class ShortcutDescriptionFormatterTests: XCTestCase {
    func testFormatsModifiersInMacConventionAndFunctionalKeyGlyphs() {
        let shortcut = KeyCombination(keyCode: 123, modifiers: [.control, .option, .shift, .command])
        XCTAssertEqual(ShortcutDescriptionFormatter.string(for: shortcut), "⌃⌥⇧⌘←")
        XCTAssertEqual(ShortcutDescriptionFormatter.string(for: KeyCombination(keyCode: 53, modifiers: [])), "⎋")
    }

    func testUnknownKeyCodeHasStableReadableFallback() {
        XCTAssertEqual(ShortcutDescriptionFormatter.string(for: KeyCombination(keyCode: UInt32.max, modifiers: [])), "Key 4294967295")
    }
}

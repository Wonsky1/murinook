import Carbon.HIToolbox
import CoreFoundation
import MurinookDomain

/// Formats a key combination using the active macOS keyboard layout and standard Mac glyphs.
@MainActor
public enum ShortcutDescriptionFormatter {
    public static func string(for combination: KeyCombination) -> String {
        var result = ""
        if combination.modifiers.contains(.control) { result += "⌃" }
        if combination.modifiers.contains(.option) { result += "⌥" }
        if combination.modifiers.contains(.shift) { result += "⇧" }
        if combination.modifiers.contains(.command) { result += "⌘" }
        result += keyGlyph(for: combination.keyCode, shifted: combination.modifiers.contains(.shift))
        return result
    }

    private static func keyGlyph(for keyCode: UInt32, shifted: Bool) -> String {
        if let glyph = specialKeyGlyphs[keyCode] { return glyph }
        guard keyCode <= UInt32(UInt16.max), let character = translatedCharacter(for: UInt16(keyCode)) else {
            return "Key \(keyCode)"
        }
        if shifted, character.count == 1, character.unicodeScalars.first?.properties.isAlphabetic == true {
            return character.uppercased()
        }
        return character
    }

    private static let specialKeyGlyphs: [UInt32: String] = [
        36: "↩︎", 48: "⇥", 49: "␣", 51: "⌫", 53: "⎋", 115: "↖︎", 116: "⇞",
        117: "⌦", 119: "↘︎", 121: "⇟", 123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7",
        100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13",
        107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
    ]

    private static func translatedCharacter(for keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layoutData = unsafeBitCast(property, to: CFData.self)
        guard let bytes = CFDataGetBytePtr(layoutData) else { return nil }
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layout in
            UCKeyTranslate(
                layout,
                keyCode,
                UInt16(kUCKeyActionDown),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysMask),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: Int(length))
    }
}

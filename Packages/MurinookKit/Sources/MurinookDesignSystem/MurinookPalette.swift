import AppKit
import SwiftUI

/// Shared adaptive colors for Murinook surfaces and controls.
public enum MurinookPalette {
    public static let page = adaptive(light: "#e9edf6", dark: "#171e2e")
    public static let page2 = adaptive(light: "#e3e8f3", dark: "#303d55")
    public static let window = adaptive(light: "#f9faff", dark: "#273147")
    public static let sidebar = adaptive(light: "#e9edf6", dark: "#171e2e")
    public static let surface = adaptive(light: "#f9faff", dark: "#273147")
    public static let surface2 = adaptive(light: "#e3e8f3", dark: "#303d55")
    public static let text = adaptive(light: "#293346", dark: "#eef1fa")
    public static let muted = adaptive(light: "#6c7890", dark: "#b0bdd4")
    public static let soft = muted
    public static let accent = adaptive(light: "#516bc0", dark: "#a6b6f2")
    public static let onAccent = adaptive(light: "#ffffff", dark: "#1b284d")
    public static let accentSoft = adaptive(light: "#e3e8f7", dark: "#34415f")
    public static let warm = adaptive(light: "#a34350", dark: "#f0a4ad")
    public static let danger = warm
    public static let border = adaptive(light: "#d6dded", dark: "#424d67")
    public static let shadow = adaptive(light: "#293346", dark: "#000000")

    public static let secondary = muted

    public static func kindBackground(_ identifier: String) -> Color {
        switch identifier {
        case "image": adaptive(light: "#dcece8", dark: "#29463e")
        case "link": adaptive(light: "#e8e9f4", dark: "#35374d")
        case "file": adaptive(light: "#f5e9de", dark: "#503d31")
        case "code": adaptive(light: "#e5ebf2", dark: "#364250")
        case "color": adaptive(light: "#e3ede7", dark: "#30483c")
        default: accentSoft
        }
    }

    public static func kindForeground(_ identifier: String) -> Color {
        switch identifier {
        case "image": adaptive(light: "#406f73", dark: "#90c5b4")
        case "link": adaptive(light: "#7174a9", dark: "#b7b8da")
        case "file": adaptive(light: "#ba794f", dark: "#dfac80")
        case "code": adaptive(light: "#6682a2", dark: "#b4c9e0")
        default: accent
        }
    }

    private static func adaptive(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(hex: value)
        })
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(srgbRed: CGFloat((value >> 16) & 0xff) / 255,
                  green: CGFloat((value >> 8) & 0xff) / 255,
                  blue: CGFloat(value & 0xff) / 255,
                  alpha: 1)
    }
}

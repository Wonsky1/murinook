import Foundation
import MurinookDomain

/// Localized command names are shared by the menu and the app's shortcut recorder.
public enum WindowActionLabels {
    public static func title(_ action: WindowAction, locale: Locale = .current) -> String {
        text("window.action." + action.rawValue, locale: locale)
    }

    public static func text(_ key: String, locale: Locale = .current) -> String {
        let bundle = Bundle.module
        let language = Bundle.preferredLocalizations(from: bundle.localizations,
            forPreferences: [locale.identifier]).first
        let localized = language.flatMap { bundle.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:)) ?? bundle
        return localized.localizedString(forKey: key, value: key, table: nil)
    }

    public static func symbol(_ action: WindowAction) -> String {
        switch action {
        case .leftHalf, .rightHalf: "rectangle.split.2x1"
        case .topHalf, .bottomHalf: "rectangle.split.1x2"
        case .topLeft, .topRight, .bottomLeft, .bottomRight: "square.grid.2x2"
        case .firstThird, .centerThird, .lastThird: "rectangle.split.3x1"
        case .maximize: "arrow.up.left.and.arrow.down.right"
        case .center: "viewfinder"
        case .restore: "arrow.uturn.backward"
        case .nextDisplay, .previousDisplay: "display.2"
        }
    }
}

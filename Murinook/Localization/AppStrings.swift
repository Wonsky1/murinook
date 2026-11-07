import Foundation
import MurinookDomain
import WindowManagementFeature

/// Native menus and window controllers need an explicit language bundle; the locale argument
/// on String(localized:) formats values but does not switch Bundle's preferred localization.
enum AppStrings {
    static func text(_ key: String, locale: Locale = .current, bundle: Bundle = .main) -> String {
        if key.hasPrefix("shortcut."),
           let action = ShortcutAction(rawValue: String(key.dropFirst("shortcut.".count)))?.windowAction {
            return WindowActionLabels.title(action, locale: locale)
        }
        if key.hasPrefix("window.") { return WindowActionLabels.text(key, locale: locale) }
        let language = Bundle.preferredLocalizations(from: bundle.localizations,
            forPreferences: [locale.identifier]).first
        let localizedBundle = language.flatMap { bundle.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:)) ?? bundle
        return localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }
}

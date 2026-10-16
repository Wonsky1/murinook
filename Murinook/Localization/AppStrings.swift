import Foundation

/// Native menus and window controllers need an explicit language bundle; the locale argument
/// on String(localized:) formats values but does not switch Bundle's preferred localization.
enum AppStrings {
    static func text(_ key: String, locale: Locale = .current, bundle: Bundle = .main) -> String {
        let language = Bundle.preferredLocalizations(from: bundle.localizations,
            forPreferences: [locale.identifier]).first
        let localizedBundle = language.flatMap { bundle.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:)) ?? bundle
        return localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }
}

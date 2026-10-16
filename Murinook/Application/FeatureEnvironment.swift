import MurinookDomain
import SwiftUI
import MurinookUseCases

struct FeatureEnvironment<Content: View>: View {
    let preferences: PreferencesStore
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .environment(\.locale, preferences.value.languageCode.map(Locale.init(identifier:)) ?? .current)
            .preferredColorScheme(preferences.value.appearance == .system ? nil :
                preferences.value.appearance == .dark ? .dark : .light)
    }
}

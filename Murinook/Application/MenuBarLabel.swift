import MurinookDomain
import MurinookUseCases
import SwiftUI

/// The label observes startup and reads nested observable preferences/update state in its view body.
struct MenuBarLabel: View {
    @ObservedObject var delegate: AppDelegate

    private var updateAvailable: Bool {
        if case .available = delegate.controller?.updates.store.state { return true }
        return false
    }

    private var locale: Locale {
        delegate.controller?.services.preferences.value.languageCode.map(Locale.init(identifier:)) ?? .current
    }

    var body: some View {
        Image(nsImage: MenuBarSymbol.image)
            .overlay(alignment: .topTrailing) {
                if updateAvailable { Circle().fill(.primary).frame(width: 4, height: 4) }
            }
            .accessibilityLabel(updateAvailable ? AppStrings.text("Murinook — update available", locale: locale) : "Murinook")
    }
}

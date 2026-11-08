import AppKit
import SwiftUI

struct ShelfIconButton: NSViewRepresentable {
    @Environment(\.locale) private var locale
    let symbol: String
    let localizationKey: String
    var isActive = false
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeNSView(context: Context) -> FirstClickButton {
        let button = FirstClickButton()
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.contentTintColor = isActive ? .controlAccentColor : .secondaryLabelColor
        button.target = context.coordinator
        button.action = #selector(Coordinator.collapse)
        button.toolTip = String(localized: String.LocalizationValue(localizationKey), bundle: .module, locale: locale)
        button.setAccessibilityLabel(String(localized: String.LocalizationValue(localizationKey), bundle: .module, locale: locale))
        return button
    }

    func updateNSView(_ button: FirstClickButton, context: Context) {
        context.coordinator.action = action
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.contentTintColor = isActive ? .controlAccentColor : .secondaryLabelColor
        let label = String(localized: String.LocalizationValue(localizationKey), bundle: .module, locale: locale)
        button.toolTip = label
        button.setAccessibilityLabel(label)
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func collapse() { action() }
    }
}

final class FirstClickButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

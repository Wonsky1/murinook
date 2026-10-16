import Observation

public enum SettingsSection: String, CaseIterable, Identifiable {
    case general, history, privacy, shortcuts, shelf, updates

    public var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .history: "clock.arrow.circlepath"
        case .privacy: "hand.raised"
        case .shortcuts: "keyboard"
        case .shelf: "tray"
        case .updates: "arrow.triangle.2.circlepath"
        }
    }
}

/// Explicit navigation lets the app open an existing settings window at a requested section.
@MainActor @Observable
public final class SettingsNavigation {
    public var selection: SettingsSection

    public init(selection: SettingsSection = .general) {
        self.selection = selection
    }
}

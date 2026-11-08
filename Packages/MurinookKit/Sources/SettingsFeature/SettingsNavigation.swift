import Observation

public enum SettingsSection: String, CaseIterable, Identifiable, Sendable {
    case clipboard, fileShelf, windowManagement, general, updates

    // Retained for callers that still open the previous settings destinations.
    case history, privacy, shortcuts, shelf

    public static let allCases: [SettingsSection] = [
        .clipboard, .fileShelf, .windowManagement, .general, .updates
    ]

    public var id: String { rawValue }

    var settingsDestination: SettingsSection {
        switch self {
        case .history, .privacy, .shortcuts: .clipboard
        case .shelf: .fileShelf
        case .clipboard, .fileShelf, .windowManagement, .general, .updates: self
        }
    }

    var symbol: String {
        switch self {
        case .clipboard: "doc.on.clipboard"
        case .fileShelf, .shelf: "tray"
        case .windowManagement: "macwindow"
        case .general: "gearshape"
        case .privacy: "hand.raised"
        case .shortcuts: "keyboard"
        case .history: "clock.arrow.circlepath"
        case .updates: "arrow.triangle.2.circlepath"
        }
    }
}

enum SettingsSectionGroup: String, CaseIterable, Identifiable, Sendable {
    case features
    case application

    var id: String { rawValue }

    var sections: [SettingsSection] {
        switch self {
        case .features: [.clipboard, .fileShelf, .windowManagement]
        case .application: [.general, .updates]
        }
    }
}

/// Explicit navigation lets the app open an existing settings window at a requested section.
@MainActor @Observable
public final class SettingsNavigation {
    private var destination: SettingsSection
    public var selection: SettingsSection {
        get { destination }
        set { destination = newValue.settingsDestination }
    }

    public init(selection: SettingsSection = .clipboard) {
        self.destination = selection.settingsDestination
    }
}

import Foundation

public enum ShelfSide: String, Codable, CaseIterable, Sendable { case left, right }
public enum AppAppearance: String, Codable, CaseIterable, Sendable { case system, light, dark }
public enum ShortcutAction: String, Codable, CaseIterable, Sendable {
    case quickAccess, library, shelf, pasteNext
    case windowLeftHalf, windowRightHalf, windowTopHalf, windowBottomHalf
    case windowTopLeft, windowTopRight, windowBottomLeft, windowBottomRight
    case windowFirstThird, windowCenterThird, windowLastThird
    case windowMaximize, windowCenter, windowRestore, windowNextDisplay, windowPreviousDisplay

    public var windowAction: WindowAction? {
        switch self {
        case .windowLeftHalf: .leftHalf
        case .windowRightHalf: .rightHalf
        case .windowTopHalf: .topHalf
        case .windowBottomHalf: .bottomHalf
        case .windowTopLeft: .topLeft
        case .windowTopRight: .topRight
        case .windowBottomLeft: .bottomLeft
        case .windowBottomRight: .bottomRight
        case .windowFirstThird: .firstThird
        case .windowCenterThird: .centerThird
        case .windowLastThird: .lastThird
        case .windowMaximize: .maximize
        case .windowCenter: .center
        case .windowRestore: .restore
        case .windowNextDisplay: .nextDisplay
        case .windowPreviousDisplay: .previousDisplay
        case .quickAccess, .library, .shelf, .pasteNext: nil
        }
    }

    public static var applicationActions: [ShortcutAction] { allCases.filter { $0.windowAction == nil } }
    public static var windowActions: [ShortcutAction] { allCases.filter { $0.windowAction != nil } }
}

public struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let command = Self(rawValue: 1 << 0)
    public static let option = Self(rawValue: 1 << 1)
    public static let control = Self(rawValue: 1 << 2)
    public static let shift = Self(rawValue: 1 << 3)
}

public struct KeyCombination: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: ShortcutModifiers
    public init(keyCode: UInt32, modifiers: ShortcutModifiers) { self.keyCode = keyCode; self.modifiers = modifiers }
    public static let defaults: [ShortcutAction: KeyCombination] = [
        .quickAccess: .init(keyCode: 9, modifiers: [.command, .shift]),
        .library: .init(keyCode: 11, modifiers: [.control, .option]),
        .shelf: .init(keyCode: 1, modifiers: [.control, .option]),
        .pasteNext: .init(keyCode: 9, modifiers: [.control, .option])
    ].merging(windowDefaults) { existing, _ in existing }
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public var captureEnabled: Bool
    public var clipboardEnabled: Bool
    public var shelfEnabled: Bool
    /// Zero disables age-based removal; any item-count limit still applies.
    public var retentionDays: Int
    /// Zero disables the unpinned item-count limit; age-based retention still applies.
    public var maxHistoryItems: Int
    public var excludedBundleIDs: [String]
    public var showsDockIcon: Bool
    public var launchAtLogin: Bool
    public var shelfSide: ShelfSide
    public var shelfOffset: Double
    public var autoRemoveShelfItems: Bool
    public var autoShowShelf: Bool
    public var languageCode: String?
    public var historyLayout: HistoryLayout
    public var appearance: AppAppearance
    public var shortcuts: [ShortcutAction: KeyCombination]
    public var activeShortcuts: [ShortcutAction: KeyCombination] {
        Dictionary(uniqueKeysWithValues: shortcuts.filter { pair in
            switch pair.key {
            case .quickAccess, .library, .pasteNext: clipboardEnabled
            case .shelf: shelfEnabled
            case .windowLeftHalf, .windowRightHalf, .windowTopHalf, .windowBottomHalf,
                 .windowTopLeft, .windowTopRight, .windowBottomLeft, .windowBottomRight,
                 .windowFirstThird, .windowCenterThird, .windowLastThird, .windowMaximize,
                 .windowCenter, .windowRestore, .windowNextDisplay, .windowPreviousDisplay:
                windowManagementEnabled
            }
        })
    }
    public var automaticallyChecksForUpdates: Bool
    public var windowManagementEnabled: Bool
    private var shortcutDefaultsVersion: Int

    private static let currentShortcutDefaultsVersion = 1

    public init(captureEnabled: Bool = true, clipboardEnabled: Bool = true, shelfEnabled: Bool = true,
                retentionDays: Int = 30, maxHistoryItems: Int = 5000,
                excludedBundleIDs: [String] = ["com.agilebits.onepassword7", "com.1password.1password"],
                showsDockIcon: Bool = false, launchAtLogin: Bool = false, shelfSide: ShelfSide = .right,
                shelfOffset: Double = 0.5, autoRemoveShelfItems: Bool = true, autoShowShelf: Bool = true, languageCode: String? = nil,
                appearance: AppAppearance = .system, historyLayout: HistoryLayout = .list, shortcuts: [ShortcutAction: KeyCombination] = KeyCombination.defaults,
                automaticallyChecksForUpdates: Bool = true, windowManagementEnabled: Bool = true) {
        self.captureEnabled = captureEnabled; self.clipboardEnabled = clipboardEnabled; self.shelfEnabled = shelfEnabled
        self.retentionDays = max(0, retentionDays); self.maxHistoryItems = maxHistoryItems == 0 ? 0 : max(1, maxHistoryItems)
        self.excludedBundleIDs = excludedBundleIDs; self.showsDockIcon = showsDockIcon; self.launchAtLogin = launchAtLogin
        self.shelfSide = shelfSide; self.shelfOffset = min(1, max(0, shelfOffset)); self.autoRemoveShelfItems = autoRemoveShelfItems
        self.autoShowShelf = autoShowShelf
        self.languageCode = languageCode; self.appearance = appearance; self.historyLayout = historyLayout; self.shortcuts = shortcuts
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        self.windowManagementEnabled = windowManagementEnabled
        self.shortcutDefaultsVersion = Self.currentShortcutDefaultsVersion
    }
    private enum CodingKeys: String, CodingKey { case captureEnabled, clipboardEnabled, shelfEnabled, retentionDays, maxHistoryItems, excludedBundleIDs, showsDockIcon, launchAtLogin, shelfSide, shelfOffset, autoRemoveShelfItems, autoShowShelf, languageCode, appearance, historyLayout, shortcuts, automaticallyChecksForUpdates, windowManagementEnabled, shortcutDefaultsVersion }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let storedDefaultsVersion = try c.decodeIfPresent(Int.self, forKey: .shortcutDefaultsVersion) ?? 0
        var shortcuts = try c.decodeIfPresent([ShortcutAction: KeyCombination].self, forKey: .shortcuts) ?? KeyCombination.defaults
        if storedDefaultsVersion < Self.currentShortcutDefaultsVersion {
            shortcuts = Self.migratingWindowShortcutDefaults(into: shortcuts)
        }
        self.init(captureEnabled: try c.decodeIfPresent(Bool.self, forKey: .captureEnabled) ?? true,
                  clipboardEnabled: try c.decodeIfPresent(Bool.self, forKey: .clipboardEnabled) ?? true,
                  shelfEnabled: try c.decodeIfPresent(Bool.self, forKey: .shelfEnabled) ?? true,
                  retentionDays: try c.decodeIfPresent(Int.self, forKey: .retentionDays) ?? 30,
                  maxHistoryItems: try c.decodeIfPresent(Int.self, forKey: .maxHistoryItems) ?? 5000,
                  excludedBundleIDs: try c.decodeIfPresent([String].self, forKey: .excludedBundleIDs) ?? ["com.agilebits.onepassword7", "com.1password.1password"],
                  showsDockIcon: try c.decodeIfPresent(Bool.self, forKey: .showsDockIcon) ?? false,
                  launchAtLogin: try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false,
                  shelfSide: try c.decodeIfPresent(ShelfSide.self, forKey: .shelfSide) ?? .right,
                  shelfOffset: try c.decodeIfPresent(Double.self, forKey: .shelfOffset) ?? 0.5,
                  autoRemoveShelfItems: try c.decodeIfPresent(Bool.self, forKey: .autoRemoveShelfItems) ?? true,
                  autoShowShelf: try c.decodeIfPresent(Bool.self, forKey: .autoShowShelf) ?? true,
                  languageCode: try c.decodeIfPresent(String.self, forKey: .languageCode),
                  appearance: try c.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system,
                  historyLayout: try c.decodeIfPresent(HistoryLayout.self, forKey: .historyLayout) ?? .list,
                  shortcuts: shortcuts,
                  automaticallyChecksForUpdates: try c.decodeIfPresent(Bool.self, forKey: .automaticallyChecksForUpdates) ?? true,
                  windowManagementEnabled: try c.decodeIfPresent(Bool.self, forKey: .windowManagementEnabled) ?? true)
        shortcutDefaultsVersion = max(storedDefaultsVersion, Self.currentShortcutDefaultsVersion)
    }

    private static func migratingWindowShortcutDefaults(
        into savedShortcuts: [ShortcutAction: KeyCombination]
    ) -> [ShortcutAction: KeyCombination] {
        var shortcuts = savedShortcuts
        for action in ShortcutAction.windowActions {
            guard shortcuts[action] == nil, let preset = KeyCombination.windowDefaults[action] else { continue }
            guard !shortcuts.values.contains(preset) else { continue }
            shortcuts[action] = preset
        }
        return shortcuts
    }
}

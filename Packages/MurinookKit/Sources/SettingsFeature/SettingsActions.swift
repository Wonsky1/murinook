import MurinookDomain

public struct SettingsActions {
    public var chooseExcludedApps: () -> Void
    public var recordShortcut: (ShortcutAction) -> Void
    public var resetShortcut: (ShortcutAction) -> Void
    public var disableShortcut: (ShortcutAction) -> Void
    public var showAccessibilityHelp: () -> Void
    public var requestPostEventAccess: () -> Void
    public var hasPostEventAccess: () -> Bool
    public var openLoginItemsSettings: () -> Void
    public var setDockIconVisible: (Bool) -> Void
    public var setLaunchAtLogin: (Bool) -> Void
    public var clearUnpinnedHistory: () -> Void
    public var unpinnedHistoryCount: () -> Int
    public var shortcutDescription: (KeyCombination?) -> String
    public var checkForUpdates: () -> Void
    public var setAutomaticUpdateChecks: (Bool) -> Void
    public var openUpdatePage: (AppRelease) -> Void
    public var downloadUpdate: (AppRelease) -> Void

    public init(chooseExcludedApps: @escaping () -> Void = {}, recordShortcut: @escaping (ShortcutAction) -> Void = { _ in },
                resetShortcut: @escaping (ShortcutAction) -> Void = { _ in },
                disableShortcut: @escaping (ShortcutAction) -> Void = { _ in },
                showAccessibilityHelp: @escaping () -> Void = {}, requestPostEventAccess: @escaping () -> Void = {},
                hasPostEventAccess: @escaping () -> Bool = { false },
                openLoginItemsSettings: @escaping () -> Void = {}, setDockIconVisible: @escaping (Bool) -> Void = { _ in },
                setLaunchAtLogin: @escaping (Bool) -> Void = { _ in },
                clearUnpinnedHistory: @escaping () -> Void = {},
                unpinnedHistoryCount: @escaping () -> Int = { 0 },
                checkForUpdates: @escaping () -> Void = {},
                setAutomaticUpdateChecks: @escaping (Bool) -> Void = { _ in },
                openUpdatePage: @escaping (AppRelease) -> Void = { _ in },
                downloadUpdate: @escaping (AppRelease) -> Void = { _ in },
                shortcutDescription: @escaping (KeyCombination?) -> String = { combination in
                    guard let combination else { return "—" }
                    var result = ""
                    if combination.modifiers.contains(.control) { result += "⌃" }
                    if combination.modifiers.contains(.option) { result += "⌥" }
                    if combination.modifiers.contains(.shift) { result += "⇧" }
                    if combination.modifiers.contains(.command) { result += "⌘" }
                    let keys: [UInt32: String] = [0: "A", 1: "S", 6: "Z", 9: "V", 11: "B"]
                    return result + (keys[combination.keyCode] ?? "Key \(combination.keyCode)")
                }) {
        self.chooseExcludedApps = chooseExcludedApps; self.recordShortcut = recordShortcut
        self.resetShortcut = resetShortcut; self.disableShortcut = disableShortcut
        self.showAccessibilityHelp = showAccessibilityHelp; self.requestPostEventAccess = requestPostEventAccess
        self.hasPostEventAccess = hasPostEventAccess
        self.openLoginItemsSettings = openLoginItemsSettings; self.setDockIconVisible = setDockIconVisible
        self.setLaunchAtLogin = setLaunchAtLogin
        self.clearUnpinnedHistory = clearUnpinnedHistory
        self.unpinnedHistoryCount = unpinnedHistoryCount
        self.shortcutDescription = shortcutDescription
        self.checkForUpdates = checkForUpdates
        self.setAutomaticUpdateChecks = setAutomaticUpdateChecks
        self.openUpdatePage = openUpdatePage
        self.downloadUpdate = downloadUpdate
    }
}

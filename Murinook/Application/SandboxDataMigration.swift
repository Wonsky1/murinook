import Foundation

enum SandboxDataMigration {
    private static let markerName = ".Murinook-unsandbox-migration-v1"

    static func migrate(bundleIdentifier: String, fileManager: FileManager = .default, defaults: UserDefaults = .standard) throws {
        let supportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let marker = supportDirectory.appendingPathComponent(markerName)
        guard !fileManager.fileExists(atPath: marker.path) else { return }

        let home = fileManager.homeDirectoryForCurrentUser
        let legacyContainer = home
            .appendingPathComponent("Library/Containers", isDirectory: true)
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("Data/Library", isDirectory: true)
        let legacyAppSupport = legacyContainer
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Murinook", isDirectory: true)
        let currentAppSupport = supportDirectory.appendingPathComponent("Murinook", isDirectory: true)

        if fileManager.fileExists(atPath: legacyAppSupport.path) {
            if fileManager.fileExists(atPath: currentAppSupport.path) {
                try copyMissingItems(from: legacyAppSupport, to: currentAppSupport, fileManager: fileManager)
            } else {
                try fileManager.moveItem(at: legacyAppSupport, to: currentAppSupport)
            }
        }

        let legacyPreferences = legacyContainer
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("\(bundleIdentifier).plist")
        try migratePreferences(from: legacyPreferences, bundleIdentifier: bundleIdentifier, fileManager: fileManager, defaults: defaults)
        try Data().write(to: marker, options: .atomic)
    }

    private static func migratePreferences(
        from source: URL,
        bundleIdentifier: String,
        fileManager: FileManager,
        defaults: UserDefaults
    ) throws {
        guard fileManager.fileExists(atPath: source.path) else { return }
        let data = try Data(contentsOf: source)
        guard let legacy = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return }
        let current = defaults.persistentDomain(forName: bundleIdentifier) ?? [:]
        defaults.setPersistentDomain(legacy.merging(current) { _, currentValue in currentValue }, forName: bundleIdentifier)
    }

    private static func copyMissingItems(from source: URL, to destination: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        for item in try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey], options: []) {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            if fileManager.fileExists(atPath: target.path) {
                let sourceIsDirectory = try item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                let targetIsDirectory = try target.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                if sourceIsDirectory && targetIsDirectory {
                    try copyMissingItems(from: item, to: target, fileManager: fileManager)
                }
                continue
            }
            try fileManager.copyItem(at: item, to: target)
        }
    }
}

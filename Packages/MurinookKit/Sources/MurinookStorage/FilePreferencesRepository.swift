import Foundation
import MurinookDomain
import MurinookUseCases

@MainActor public final class FilePreferencesRepository: PreferencesRepository {
    private let url: URL
    private var cachedValue: AppPreferences

    public init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let preferencesURL = directory.appendingPathComponent("Preferences.json")
        url = preferencesURL
        if FileManager.default.fileExists(atPath: preferencesURL.path) {
            let data = try Data(contentsOf: preferencesURL)
            cachedValue = try JSONDecoder().decode(AppPreferences.self, from: data)
        } else {
            cachedValue = AppPreferences()
        }
    }

    public func load() -> AppPreferences { cachedValue }

    public func save(_ value: AppPreferences) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
        cachedValue = value
    }
}

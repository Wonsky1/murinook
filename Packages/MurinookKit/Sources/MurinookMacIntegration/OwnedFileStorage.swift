import Foundation

/// Disk copies run away from the UI actor and preserve filenames in separate item directories.
actor OwnedFileStorage {
    private let directory: URL

    init(directory: URL) { self.directory = directory }

    func copy(_ source: URL) throws -> URL {
        try Self.copy(source, into: directory)
    }

    nonisolated static func copy(_ source: URL, into directory: URL) throws -> URL {
        let manager = FileManager.default
        let container = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destination = container.appendingPathComponent(source.lastPathComponent)
        do {
            try manager.createDirectory(at: container, withIntermediateDirectories: true)
            try manager.copyItem(at: source, to: destination)
            return destination
        } catch {
            try? manager.removeItem(at: container)
            throw FileImportError.storageFailed(error.localizedDescription)
        }
    }
}

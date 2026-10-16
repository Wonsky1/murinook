import Foundation
import MurinookDomain
import MurinookUseCases

@MainActor public final class FileContentRepository: ContentRepository {
    private let storage: FileContentStorage

    public init(directory: URL, fileManager: FileManager = .default) throws {
        let contentDirectory = directory.appendingPathComponent("Content", isDirectory: true)
        try fileManager.createDirectory(at: contentDirectory, withIntermediateDirectories: true)
        storage = FileContentStorage(contentDirectory: contentDirectory)
    }

    public func put(_ content: ClipContent, id: UUID) async throws {
        try await storage.put(content, id: id)
    }

    public func get(_ id: UUID) async throws -> ClipContent {
        try await storage.get(id)
    }

    public func remove(_ ids: Set<UUID>) async throws {
        try await storage.remove(ids)
    }

    /// Removes stale content payloads and all unreferenced app-owned material under ImportedFiles.
    /// Payloads are decoded before the first deletion, so corruption aborts the entire sweep.
    public func pruneUnreferenced(
        retaining ids: Set<UUID>,
        protectedImportURLs: Set<URL> = []
    ) async throws {
        try await storage.pruneUnreferenced(retaining: ids, protectedImportURLs: protectedImportURLs)
    }
}

/// Actor isolation makes payload writes, reads, removals and pruning one serialized file operation stream.
private actor FileContentStorage {
    private let contentDirectory: URL
    private let importedDirectory: URL
    private let fileManager = FileManager.default

    init(contentDirectory: URL) {
        self.contentDirectory = contentDirectory.standardizedFileURL
        importedDirectory = contentDirectory.deletingLastPathComponent()
            .appendingPathComponent("ImportedFiles", isDirectory: true).standardizedFileURL
    }

    func put(_ content: ClipContent, id: UUID) throws {
        let data = try JSONEncoder().encode(content)
        try data.write(to: payloadURL(id), options: .atomic)
    }

    func get(_ id: UUID) throws -> ClipContent {
        let data = try Data(contentsOf: payloadURL(id))
        return try JSONDecoder().decode(ClipContent.self, from: data)
    }

    func remove(_ ids: Set<UUID>) throws {
        for id in ids {
            let url = payloadURL(id)
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
        }
    }

    func pruneUnreferenced(retaining ids: Set<UUID>, protectedImportURLs: Set<URL>) throws {
        let payloadURLs = try fileManager.contentsOfDirectory(at: contentDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "payload" }
        var payloadIDs = Set<UUID>()
        var retainedPaths = Set<String>()

        // Decode every payload before mutating anything. Even a malformed orphan must halt cleanup.
        for url in payloadURLs {
            let data = try Data(contentsOf: url)
            let content = try JSONDecoder().decode(ClipContent.self, from: data)
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
            payloadIDs.insert(id)
            if ids.contains(id) {
                for reference in content.files {
                    if let path = managedPath(reference.url) { retainedPaths.insert(path) }
                }
            }
        }

        for url in protectedImportURLs {
            if let path = managedPath(url) { retainedPaths.insert(path) }
        }

        // Refuse to inspect a substituted symlink, but still prune payloads if imports are absent.
        if let rootInfo = try? fileManager.attributesOfItem(atPath: importedDirectory.path),
           (rootInfo[.type] as? FileAttributeType) == .typeDirectory {
            let retainedDirectoryPaths = Set(retainedPaths.filter { path in
                guard let attributes = try? fileManager.attributesOfItem(atPath: path) else { return false }
                return (attributes[.type] as? FileAttributeType) == .typeDirectory
            })
            try sweep(
                directory: importedDirectory,
                retainedPaths: retainedPaths,
                retainedDirectoryPaths: retainedDirectoryPaths
            )
        }

        let orphanIDs = payloadIDs.subtracting(ids)
        for id in orphanIDs {
            let url = payloadURL(id)
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
        }
    }

    private func payloadURL(_ id: UUID) -> URL {
        contentDirectory.appendingPathComponent(id.uuidString).appendingPathExtension("payload")
    }

    /// Uses lexical paths. Resolving symlinks here could turn an in-tree link into authority over an external path.
    private func managedPath(_ url: URL) -> String? {
        let root = importedDirectory.standardizedFileURL.path
        let candidate = url.standardizedFileURL.path
        guard candidate.hasPrefix(root + "/") else { return nil }
        return candidate
    }

    private func sweep(directory: URL, retainedPaths: Set<String>, retainedDirectoryPaths: Set<String>) throws {
        let entries = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for entry in entries {
            let path = entry.standardizedFileURL.path
            if retainedPaths.contains(path)
                || retainedDirectoryPaths.contains(where: { path.hasPrefix($0 + "/") }) {
                continue
            }

            let attributes = try fileManager.attributesOfItem(atPath: entry.path)
            let type = attributes[.type] as? FileAttributeType
            if type == .typeDirectory {
                try sweep(
                    directory: entry,
                    retainedPaths: retainedPaths,
                    retainedDirectoryPaths: retainedDirectoryPaths
                )
                // A now-empty unreferenced item container is reclaimed as well.
                if (try fileManager.contentsOfDirectory(atPath: entry.path)).isEmpty {
                    try fileManager.removeItem(at: entry)
                }
            } else if retainedPaths.contains(where: { $0.hasPrefix(path + "/") }) {
                // A malformed or temporarily replaced ancestor must not be removed under a retained path.
                continue
            } else {
                // Symbolic links are leaf entries here; removeItem unlinks the link and never follows its target.
                try fileManager.removeItem(at: entry)
            }
        }
    }
}

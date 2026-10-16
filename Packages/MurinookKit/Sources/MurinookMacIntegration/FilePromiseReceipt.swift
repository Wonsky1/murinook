import AppKit
import Foundation

/// A file-promise receipt started from an active AppKit drop callback.
/// Await `value()` after the callback returns to collect the materialized files.
@MainActor
public final class PromiseReceiveBatch {
    private let completion: Task<[ImportedFile], Error>

    init(group: PromiseReceiveGroup) {
        completion = Task { @MainActor in try await group.value() }
    }

    public func value() async throws -> [ImportedFile] {
        try await completion.value
    }
}

/// Aggregates promise callbacks, moves fulfilled files into owned storage, and
/// removes the temporary receive directory after all callbacks have settled.
@MainActor
final class PromiseReceiveGroup {
    private var expected: Int
    private let stagingDirectory: URL
    private let destinationDirectory: URL
    private let fileManager: FileManager
    private var continuation: CheckedContinuation<[ImportedFile], Error>?
    private var results: [ImportedFile] = []
    private var failures: [Error] = []
    private var callbacks = 0
    private var isFinished = false

    init(stagingDirectory: URL, destinationDirectory: URL, fileManager: FileManager) {
        expected = 0
        self.stagingDirectory = stagingDirectory
        self.destinationDirectory = destinationDirectory
        self.fileManager = fileManager
    }

    func value() async throws -> [ImportedFile] {
        try await withCheckedThrowingContinuation { continuation in
            if isFinished {
                resume(continuation)
            } else {
                self.continuation = continuation
            }
        }
    }

    func record(url: URL?, error: Error?) {
        guard !isFinished else { return }
        callbacks += 1
        if let error { failures.append(error) }
        else if let url {
            do {
                let name = url.lastPathComponent
                let container = destinationDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try fileManager.createDirectory(at: container, withIntermediateDirectories: true)
                let target = container.appendingPathComponent(name)
                try fileManager.moveItem(at: url, to: target)
                let type = (try? target.resourceValues(forKeys: [.contentTypeKey]).contentType)?.identifier
                let byteCount = try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize
                results.append(ImportedFile(url: target, displayName: name, typeIdentifier: type,
                    bookmark: nil, isOwnedCopy: true, byteCount: byteCount))
            } catch {
                failures.append(error)
            }
        }
        if expected > 0, callbacks >= expected { finish() }
    }

    func setExpectedCount(_ expected: Int) {
        self.expected = max(1, expected)
        if callbacks >= self.expected { finish() }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        try? fileManager.removeItem(at: stagingDirectory)
        guard let continuation else { return }
        self.continuation = nil
        resume(continuation)
    }

    private func resume(_ continuation: CheckedContinuation<[ImportedFile], Error>) {
        if !results.isEmpty { continuation.resume(returning: results) }
        else {
            continuation.resume(throwing: FileImportError.promiseFailed(
                failures.first?.localizedDescription ?? "No files were delivered."))
        }
    }
}

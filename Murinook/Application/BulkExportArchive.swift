import Foundation
import MurinookDomain

/// Streams one payload at a time, keeping large multi-item exports off the UI actor.
actor BulkExportArchive {
    private let url: URL
    private let handle: FileHandle
    private var count = 0
    private var closed = false

    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("Murinook-Export-\(UUID().uuidString).json")
        try Data("[\n".utf8).write(to: url, options: .atomic)
        handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
    }
    func append(clip: Clip, content: ClipContent) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if count > 0 { try handle.write(contentsOf: Data(",\n".utf8)) }
        try handle.write(contentsOf: encoder.encode(ExportedClip(clip: clip, content: content)))
        count += 1
    }
    func finish() throws -> URL {
        try handle.write(contentsOf: Data("\n]\n".utf8))
        try handle.close()
        closed = true
        return url
    }
    func dispose() {
        if !closed { try? handle.close(); closed = true }
        try? FileManager.default.removeItem(at: url)
    }
}

private nonisolated struct ExportedClip: Codable {
    let clip: Clip
    let content: ClipContent
}

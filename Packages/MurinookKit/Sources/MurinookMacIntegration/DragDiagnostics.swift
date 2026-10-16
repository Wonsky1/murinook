import Foundation
import OSLog

/// Local, bounded metadata tracing for reproducing native drag failures.
/// Callers supply descriptions/counts only, never payload or bookmark bytes.
@MainActor
public final class DragDiagnostics {
    public let fileURL: URL
    public let runID = UUID().uuidString
    public private(set) var currentDragID: String?
    private let writer: DragDiagnosticWriter
    private let clock = ISO8601DateFormatter()
    private var sequence = 0
    private var currentGeneration: Int?
    private var fileIDs: [String: String] = [:]

    public init(directory: URL, maximumFileBytes: Int = 2 * 1_024 * 1_024) {
        fileURL = directory.appendingPathComponent("drag-diagnostics.jsonl")
        writer = DragDiagnosticWriter(fileURL: fileURL, maximumBytes: maximumFileBytes)
        clock.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        event("diagnostics.started", fields: ["format": "1", "os": ProcessInfo.processInfo.operatingSystemVersionString])
    }

    @discardableResult
    public func beginDrag(changeCount: Int, fields: [String: String] = [:]) -> String {
        if currentGeneration != changeCount || currentDragID == nil {
            currentGeneration = changeCount
            currentDragID = UUID().uuidString
            fileIDs.removeAll(keepingCapacity: true)
            event("drag.begin", fields: fields.merging(["pasteboard_generation": String(changeCount)]) { _, new in new })
        }
        return currentDragID!
    }

    public func event(_ name: String, fields: [String: String] = [:], dragID: String? = nil) {
        sequence += 1
        var boundedFields: [String: String] = [:]
        for key in fields.keys.sorted().prefix(40) {
            boundedFields[String(key.prefix(80))] = String(fields[key, default: ""].prefix(1_024))
        }
        let record = Record(timestamp: clock.string(from: Date()), uptime: ProcessInfo.processInfo.systemUptime,
            runID: runID, pid: ProcessInfo.processInfo.processIdentifier, sequence: sequence,
            dragID: dragID ?? currentDragID, event: String(name.prefix(120)), fields: boundedFields)
        guard var data = try? JSONEncoder().encode(record) else { return }
        data.append(0x0A)
        writer.append(data)
    }

    /// Stable within a gesture; paths and file contents are not written to the log.
    public func fileFields(_ url: NSURL) -> [String: String] {
        let identity = url.absoluteString ?? ""
        let id: String
        if let existing = fileIDs[identity] { id = existing }
        else {
            id = UUID().uuidString
            if fileIDs.count < 256 { fileIDs[identity] = id }
        }
        return ["file_id": id, "file_name": url.lastPathComponent ?? "",
            "file_extension": url.pathExtension ?? "", "is_file_url": String(url.isFileURL),
            "path_length": String(url.path?.utf8.count ?? 0)]
    }

    public func errorFields(_ error: Error) -> [String: String] {
        var fields: [String: String] = [:]
        var current: NSError? = error as NSError
        for depth in 0..<3 {
            guard let value = current else { break }
            let prefix = depth == 0 ? "error" : "underlying_\(depth)"
            fields["\(prefix)_domain"] = value.domain
            fields["\(prefix)_code"] = String(value.code)
            // Descriptions can embed document contents or complete paths. Codes suffice.
            current = value.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return fields
    }

    public func flush() async { await writer.flush() }

    private struct Record: Encodable {
        let timestamp: String
        let uptime: TimeInterval
        let runID: String
        let pid: Int32
        let sequence: Int
        let dragID: String?
        let event: String
        let fields: [String: String]
    }
}

/// All disk I/O runs on one queue so instrumentation cannot block the drag callback.
private final class DragDiagnosticWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "wonsky.Murinook.drag-diagnostics", qos: .utility)
    private let fileURL: URL
    private let previousURL: URL
    private let maximumBytes: Int
    private let logger = Logger(subsystem: "wonsky.Murinook", category: "DragDiagnostics")

    init(fileURL: URL, maximumBytes: Int) {
        self.fileURL = fileURL
        previousURL = fileURL.appendingPathExtension("previous")
        self.maximumBytes = max(1_024, maximumBytes)
    }

    func append(_ data: Data) {
        queue.async { [self] in
            do {
                guard data.count <= maximumBytes else { return }
                let manager = FileManager.default
                try manager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let size = (try? manager.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.intValue ?? 0
                if size + data.count > maximumBytes, manager.fileExists(atPath: fileURL.path) {
                    if manager.fileExists(atPath: previousURL.path) { try manager.removeItem(at: previousURL) }
                    try manager.moveItem(at: fileURL, to: previousURL)
                }
                if !manager.fileExists(atPath: fileURL.path) {
                    guard manager.createFile(atPath: fileURL.path, contents: nil,
                        attributes: [.posixPermissions: 0o600]) else { throw CocoaError(.fileWriteUnknown) }
                }
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                let value = error as NSError
                logger.error("Cannot write local drag diagnostics: \(value.domain, privacy: .public) \(value.code)")
            }
        }
    }

    func flush() async {
        await withCheckedContinuation { continuation in queue.async { continuation.resume() } }
    }
}

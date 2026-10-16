import AppKit
import Foundation
import UniformTypeIdentifiers

public struct ExternalDragCandidate: Sendable, Hashable {
    public let changeCount: Int
    public let typeIdentifiers: [String]
    public let containsFilePromise: Bool
}

/// Deliberately exposes only drag-pasteboard metadata. Hover detection must not
/// request file representations before the user drops onto the destination.
@MainActor
protocol ExternalDragPasteboardSource: AnyObject {
    var changeCount: Int { get }
    var types: [NSPasteboard.PasteboardType]? { get }
}

@MainActor
private final class NSPasteboardDragSource: ExternalDragPasteboardSource {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard) { self.pasteboard = pasteboard }

    var changeCount: Int { pasteboard.changeCount }
    var types: [NSPasteboard.PasteboardType]? { pasteboard.types }
}

/// Observes the system drag pasteboard. A changed, valid drag pasteboard is required;
/// mouse movement and text selection by themselves never produce a candidate.
@MainActor
public final class ExternalDragMonitor {
    public var onCandidate: (@MainActor (ExternalDragCandidate) -> Void)?
    public var onDragEnded: (@MainActor () -> Void)?
    public var isInternalDragActive = false

    private let pasteboardSource: any ExternalDragPasteboardSource
    private let diagnostics: DragDiagnostics?
    private var timer: Timer?
    private var lastChangeCount: Int
    private var activeChangeCount: Int?
    private var includesText: Bool
    private var diagnosticDragID: String?
    private let promiseTypes = Set(NSFilePromiseReceiver.readableDraggedTypes)

    public init(pasteboard: NSPasteboard = NSPasteboard(name: .drag), includesText: Bool = true, diagnostics: DragDiagnostics? = nil) {
        let source = NSPasteboardDragSource(pasteboard: pasteboard)
        self.pasteboardSource = source
        self.includesText = includesText
        self.diagnostics = diagnostics
        self.lastChangeCount = source.changeCount
    }

    init(source: any ExternalDragPasteboardSource, includesText: Bool = true, diagnostics: DragDiagnostics? = nil) {
        self.pasteboardSource = source
        self.includesText = includesText
        self.diagnostics = diagnostics
        self.lastChangeCount = source.changeCount
    }

    public func setIncludesText(_ value: Bool) { includesText = value }

    public func start(pollInterval: TimeInterval = 0.05) {
        guard timer == nil else { return }
        diagnostics?.event("external-monitor.start", fields: ["pollInterval": String(max(0.02, pollInterval))])
        let timer = Timer(timeInterval: max(0.02, pollInterval), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        diagnostics?.event("external-monitor.stop", fields: ["wasActive": String(activeChangeCount != nil)])
        timer?.invalidate()
        timer = nil
        activeChangeCount = nil
    }

    private func poll() {
        poll(buttonDown: NSEvent.pressedMouseButtons & 1 != 0)
    }

    /// One polling step with input injected for deterministic policy tests.
    func poll(buttonDown: Bool) {
        let generation = pasteboardSource.changeCount
        guard buttonDown else {
            if let endedGeneration = activeChangeCount {
                diagnostics?.event("external-monitor.ended", fields: ["changeCount": String(endedGeneration)], dragID: diagnosticDragID)
                activeChangeCount = nil
                diagnosticDragID = nil
                onDragEnded?()
            }
            lastChangeCount = generation
            return
        }
        guard generation != lastChangeCount else { return }
        lastChangeCount = generation
        if isInternalDragActive {
            diagnostics?.event("external-monitor.ignored-internal", fields: ["changeCount": String(generation)])
            return
        }
        guard let candidate = validatedCandidate(generation: generation) else {
            diagnostics?.event("external-monitor.ignored-unsupported", fields: ["changeCount": String(generation), "types": (pasteboardSource.types ?? []).map(\.rawValue).joined(separator: ",")])
            return
        }
        activeChangeCount = generation
        let fields = ["changeCount": String(generation), "types": candidate.typeIdentifiers.joined(separator: ","), "containsFilePromise": String(candidate.containsFilePromise)]
        diagnosticDragID = diagnostics?.beginDrag(changeCount: generation, fields: fields)
        diagnostics?.event("external-monitor.candidate", fields: fields, dragID: diagnosticDragID)
        onCandidate?(candidate)
    }

    private func validatedCandidate(generation: Int) -> ExternalDragCandidate? {
        guard let nativeTypes = pasteboardSource.types else { return nil }
        let identifiers = nativeTypes.map(\.rawValue)
        let hasPromise = !promiseTypes.isDisjoint(with: identifiers)
        let hasImage = identifiers.contains { identifier in
            guard let type = UTType(identifier) else { return false }
            return type.conforms(to: .image)
        }
        let supported = identifiers.contains(NSPasteboard.PasteboardType.fileURL.rawValue)
            || hasPromise
            || hasImage
            || (includesText && identifiers.contains(NSPasteboard.PasteboardType.string.rawValue))
        guard supported else { return nil }
        // Inspect declarations only until the user drops. Reading file representations
        // here can consume a sandbox extension before AppKit grants destination access.
        // The native destination validates the actual payload in performDragOperation.
        return ExternalDragCandidate(changeCount: generation, typeIdentifiers: identifiers, containsFilePromise: hasPromise)
    }
}

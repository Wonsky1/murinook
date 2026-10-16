import AppKit
import UniformTypeIdentifiers

/// A single AppKit drop destination hosting the shelf content and routing native drops.
@MainActor
public final class ShelfDropDestinationView: NSView {
    public var onDragEntered: (() -> Void)?
    public var onDrop: ((NSPasteboard) -> Bool)?
    public var isDropEnabled: () -> Bool = { true }
    private let diagnostics: DragDiagnostics?
    private var diagnosticDragID: String?
    private var lastLoggedAcceptance: String?

    public init(contentView: NSView, diagnostics: DragDiagnostics? = nil) {
        self.diagnostics = diagnostics
        super.init(frame: .zero)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        let pasteboardTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
            + Self.supportedTypeIdentifiers.map { NSPasteboard.PasteboardType($0) }
        registerForDraggedTypes(pasteboardTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let acceptance = acceptance(for: sender)
        diagnosticDragID = diagnostics?.beginDrag(changeCount: sender.draggingPasteboard.changeCount, fields: diagnosticFields(sender, acceptance: acceptance))
        logAcceptance(acceptance, sender: sender, event: "drop.enter")
        diagnostics?.event("drop.enter", fields: diagnosticFields(sender, acceptance: acceptance), dragID: diagnosticDragID)
        guard acceptance.accepted else { return [] }
        onDragEntered?()
        return .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let acceptance = acceptance(for: sender)
        logAcceptance(acceptance, sender: sender, event: "drop.update")
        return acceptance.accepted ? .copy : []
    }

    public override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let acceptance = acceptance(for: sender)
        diagnostics?.event("drop.prepare", fields: diagnosticFields(sender, acceptance: acceptance), dragID: diagnosticDragID)
        return acceptance.accepted
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let acceptance = acceptance(for: sender)
        let fields = diagnosticFields(sender, acceptance: acceptance)
        let dragID = diagnostics?.beginDrag(changeCount: sender.draggingPasteboard.changeCount, fields: fields) ?? diagnosticDragID
        diagnostics?.event("drop.perform", fields: fields, dragID: dragID)
        guard acceptance.accepted, let onDrop else {
            diagnostics?.event("drop.perform-rejected", fields: fields, dragID: dragID)
            return false
        }
        let succeeded = onDrop(sender.draggingPasteboard)
        diagnostics?.event("drop.perform-result", fields: fields.merging(["succeeded": String(succeeded)]) { _, new in new }, dragID: dragID)
        return succeeded
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        var fields: [String: String] = [:]
        if let info = sender {
            fields["changeCount"] = String(info.draggingPasteboard.changeCount)
            fields["types"] = (info.draggingPasteboard.types ?? []).map(\.rawValue).joined(separator: ",")
            fields["sourceMask"] = String(describing: info.draggingSourceOperationMask)
            fields["destinationX"] = String(describing: info.draggingLocation.x)
            fields["destinationY"] = String(describing: info.draggingLocation.y)
            fields["localSource"] = String(info.draggingSource != nil)
        }
        diagnostics?.event("drop.exited", fields: fields, dragID: diagnosticDragID)
        lastLoggedAcceptance = nil
    }

    public override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        // Logging must not re-run acceptance or request another representation.
        diagnostics?.event("drop.conclude", fields: ["last_acceptance": lastLoggedAcceptance ?? "unknown"], dragID: diagnosticDragID)
        diagnosticDragID = nil
        lastLoggedAcceptance = nil
    }

    private func acceptance(for sender: NSDraggingInfo) -> (accepted: Bool, reason: String, types: [String]) {
        let pasteboard = sender.draggingPasteboard
        let rawTypeList = pasteboard.types?.map(\.rawValue) ?? []
        let rawTypes = Set(rawTypeList)
        guard sender.draggingSourceOperationMask.contains(.copy) else { return (false, "source-mask-no-copy", rawTypeList) }
        guard isDropEnabled() else { return (false, "drop-disabled", rawTypeList) }
        guard !rawTypes.isEmpty else { return (false, "no-types", rawTypeList) }

        if Self.supportedTypeIdentifiers.contains(where: rawTypes.contains) { return (true, "exact-supported-type", rawTypeList) }

        let supportedTypes = Self.supportedUTTypes
        let hasConformingType = rawTypes.contains { identifier in
            guard let type = UTType(identifier) else { return false }
            return supportedTypes.contains(where: type.conforms(to:))
        }
        if hasConformingType { return (true, "conforming-supported-type", rawTypeList) }

        let promiseTypes = Set(NSFilePromiseReceiver.readableDraggedTypes)
        guard !promiseTypes.isDisjoint(with: rawTypes) else { return (false, "unsupported-types", rawTypeList) }
        return (!(pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver] ?? []).isEmpty,
                "file-promise-receiver-probe", rawTypeList)
    }

    private func diagnosticFields(_ sender: NSDraggingInfo, acceptance: (accepted: Bool, reason: String, types: [String])) -> [String: String] {
        let fields: [String: String] = ["changeCount": String(sender.draggingPasteboard.changeCount),
            "types": acceptance.types.joined(separator: ","),
            "sourceMask": String(describing: sender.draggingSourceOperationMask),
            "destinationX": String(describing: sender.draggingLocation.x), "destinationY": String(describing: sender.draggingLocation.y),
            "localSource": String(sender.draggingSource != nil),
            "accepted": String(acceptance.accepted), "reason": acceptance.reason]
        return fields
    }

    private func logAcceptance(_ acceptance: (accepted: Bool, reason: String, types: [String]), sender: NSDraggingInfo, event: String) {
        guard event == "drop.enter" || lastLoggedAcceptance != "\(acceptance.accepted):\(acceptance.reason)" else { return }
        lastLoggedAcceptance = "\(acceptance.accepted):\(acceptance.reason)"
        diagnostics?.event("\(event).acceptance", fields: diagnosticFields(sender, acceptance: acceptance), dragID: diagnosticDragID)
    }

    private static let supportedTypeIdentifiers = [
        UTType.fileURL.identifier,
        UTType.url.identifier,
        UTType.text.identifier,
        UTType.html.identifier,
        UTType.rtf.identifier,
        UTType.image.identifier,
        UTType.item.identifier,
        UTType.data.identifier,
    ]

    private static let supportedUTTypes: [UTType] = supportedTypeIdentifiers.compactMap(UTType.init)
}

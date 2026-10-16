import AppKit
import Foundation
import MurinookDomain

public struct ClipboardWriteToken: Sendable, Hashable {
    public let changeCount: Int
    public init(changeCount: Int) { self.changeCount = changeCount }
}

@MainActor
public final class ClipboardContentWriter {
    private let pasteboard: NSPasteboard
    private let writeRegistry: ClipboardWriteRegistry

    public init(pasteboard: NSPasteboard = .general, writeRegistry: ClipboardWriteRegistry) {
        self.pasteboard = pasteboard
        self.writeRegistry = writeRegistry
    }

    @discardableResult
    public func write(_ items: [ClipboardItemSnapshot]) throws -> ClipboardWriteToken {
        pasteboard.clearContents()
        let nativeItems = items.map { item -> NSPasteboardItem in
            let native = NSPasteboardItem()
            for representation in item.representations {
                native.setData(representation.data, forType: NSPasteboard.PasteboardType(representation.typeIdentifier))
            }
            return native
        }
        guard nativeItems.isEmpty || pasteboard.writeObjects(nativeItems) else {
            throw ClipboardWriteError.pasteboardRejectedContent
        }
        let token = ClipboardWriteToken(changeCount: pasteboard.changeCount)
        writeRegistry.record(token.changeCount)
        return token
    }

    @discardableResult
    public func write(_ content: ClipContent) throws -> ClipboardWriteToken {
        try write(content.clipboardItems)
    }

    public func writePlainText(_ text: String) throws -> ClipboardWriteToken {
        let data = Data(text.utf8)
        return try write([ClipboardItemSnapshot(representations: [
            ClipboardRepresentationSnapshot(typeIdentifier: NSPasteboard.PasteboardType.string.rawValue, data: data)
        ])])
    }
}

public enum ClipboardWriteError: Error, Sendable {
    case pasteboardRejectedContent
}

import AppKit
import Foundation
import MurinookDomain

/// Creates native drag writers while preserving each clipboard item and all its representations.
@MainActor
public struct DragItemFactory {
    private let bookmarks: BookmarkAdapter

    public init(bookmarks: BookmarkAdapter) {
        self.bookmarks = bookmarks
    }

    public func makeItems(for content: ClipContent) throws -> [NSDraggingItem] {
        try content.clipboardItems.map { snapshot in
            if let file = snapshot.files.first {
                let url = try resolvedURL(for: file)
                let draggingItem = NSDraggingItem(pasteboardWriter: url as NSURL)
                let image = NSWorkspace.shared.icon(forFile: url.path)
                image.size = NSSize(width: 48, height: 48)
                draggingItem.setDraggingFrame(NSRect(x: 0, y: 0, width: 48, height: 48), contents: image)
                return draggingItem
            }
            let item = NSPasteboardItem()
            for representation in snapshot.representations {
                let type = NSPasteboard.PasteboardType(representation.typeIdentifier)
                if representation.typeIdentifier == NSPasteboard.PasteboardType.fileURL.rawValue,
                   let file = snapshot.files.first {
                    let url = try resolvedURL(for: file)
                    try bookmarks.withAccess(to: url) {
                        guard item.setData(Data(url.absoluteString.utf8), forType: .fileURL) else {
                            throw DragItemFactoryError.couldNotWriteFileURL(url)
                        }
                    }
                } else if !item.setData(representation.data, forType: type) {
                    throw DragItemFactoryError.couldNotWriteRepresentation(representation.typeIdentifier)
                }
            }
            let draggingItem = NSDraggingItem(pasteboardWriter: item)
            let image = NSImage(systemSymbolName: content.kind.symbolName, accessibilityDescription: nil)
            draggingItem.setDraggingFrame(NSRect(x: 0, y: 0, width: 48, height: 48), contents: image)
            return draggingItem
        }
    }

    private func resolvedURL(for file: FileReference) throws -> URL {
        guard let bookmark = file.bookmark else { return file.url }
        return try bookmarks.resolveBookmark(bookmark).url
    }
}

public enum DragItemFactoryError: Error, LocalizedError, Sendable {
    case couldNotWriteFileURL(URL)
    case couldNotWriteRepresentation(String)

    public var errorDescription: String? {
        switch self {
        case .couldNotWriteFileURL(let url): "Could not add file URL to drag: \(url.lastPathComponent)"
        case .couldNotWriteRepresentation(let identifier): "Could not add representation to drag: \(identifier)"
        }
    }
}

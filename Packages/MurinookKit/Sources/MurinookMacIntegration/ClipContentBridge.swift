import Foundation
import MurinookDomain

public extension ClipboardItemSnapshot {
    init(content: ClipContent) {
        representations = content.representations.map {
            ClipboardRepresentationSnapshot(typeIdentifier: $0.typeIdentifier, data: $0.data)
        }
        files = content.files
    }

    var clipContent: ClipContent {
        ClipContent(
            representations: representations.map { ClipRepresentation(typeIdentifier: $0.typeIdentifier, data: $0.data) },
            files: files
        )
    }
}

public extension ClipboardSnapshot {
    /// Maintains pasteboard item boundaries; each returned value keeps every representation of its source item.
    var clipContents: [ClipContent] { items.map(\.clipContent) }
    func toContents() -> [ClipContent] { clipContents }
}

public extension ClipContent {
    /// Reconstructs one pasteboard item per file, plus a separate item for non-file representations.
    var clipboardItems: [ClipboardItemSnapshot] {
        var result: [ClipboardItemSnapshot] = []
        let fileURLIdentifiers: Set<String> = ["public.file-url"]
        let nonFileRepresentations = files.isEmpty ? representations : representations.filter {
            !fileURLIdentifiers.contains($0.typeIdentifier)
        }
        if !nonFileRepresentations.isEmpty {
            result.append(ClipboardItemSnapshot(representations: nonFileRepresentations.map {
                ClipboardRepresentationSnapshot(typeIdentifier: $0.typeIdentifier, data: $0.data)
            }))
        }
        result.append(contentsOf: files.map { file in
            ClipboardItemSnapshot(representations: [
                ClipboardRepresentationSnapshot(typeIdentifier: "public.file-url", data: Data(file.url.absoluteString.utf8))
            ], files: [file])
        })
        return result
    }
}

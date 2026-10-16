import AppKit
import ImageIO
import MurinookDomain
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// Persists a small preview independently of the referenced file's bytes.
@MainActor
public final class ContentVisualAdapter {
    private let bookmarks: BookmarkAdapter
    private let pixelSize = 96

    public init(bookmarks: BookmarkAdapter) { self.bookmarks = bookmarks }

    public func addingVisuals(to content: ClipContent) async -> ClipContent {
        var result = content
        for index in result.files.indices where result.files[index].iconData == nil {
            let file = result.files[index]
            guard let url = try? file.bookmark.map(bookmarks.resolve) ?? file.url else { continue }
            let acquired = bookmarks.startAccessing(url)
            result.files[index].iconData = await preview(for: url)
            if acquired { bookmarks.stopAccessing(url) }
        }
        if result.iconData == nil { result.iconData = result.files.first?.iconData }
        if result.iconData == nil, result.kind == .image {
            for representation in result.representations {
                guard let source = CGImageSourceCreateWithData(representation.data as CFData, nil),
                      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: pixelSize,
                        kCGImageSourceCreateThumbnailWithTransform: true
                      ] as CFDictionary) else { continue }
                result.iconData = Self.png(image)
                break
            }
        }
        return result
    }

    private func preview(for url: URL) async -> Data? {
        let request = QLThumbnailGenerator.Request(fileAt: url,
            size: CGSize(width: pixelSize, height: pixelSize), scale: 1, representationTypes: .thumbnail)
        let thumbnail: Data? = await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation.flatMap { Self.png($0.cgImage) })
            }
        }
        if let thumbnail { return thumbnail }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixelSize,
            pixelsHigh: pixelSize, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        guard let bitmap, let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        icon.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
    }

    nonisolated private static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

import Foundation

public struct ClipRepresentation: Codable, Hashable, Sendable {
    public var typeIdentifier: String
    public var data: Data
    public init(typeIdentifier: String, data: Data) { self.typeIdentifier = typeIdentifier; self.data = data }
}

public struct FileReference: Codable, Hashable, Sendable {
    public var url: URL
    public var bookmark: Data?
    public var isOwnedCopy: Bool
    public var iconData: Data?
    public var byteCount: Int?
    public init(url: URL, bookmark: Data? = nil, isOwnedCopy: Bool = false, byteCount: Int? = nil, iconData: Data? = nil) {
        self.url = url; self.bookmark = bookmark; self.isOwnedCopy = isOwnedCopy; self.byteCount = byteCount; self.iconData = iconData
    }
}

public struct ClipContent: Codable, Hashable, Sendable {
    public var representations: [ClipRepresentation]
    public var iconData: Data?
    public var files: [FileReference]
    public init(representations: [ClipRepresentation] = [], files: [FileReference] = [], iconData: Data? = nil) {
        self.representations = representations; self.files = files; self.iconData = iconData
    }
    public var plainText: String? {
        guard let data = representations.first(where: { ["public.utf8-plain-text", "public.plain-text", "NSStringPboardType"].contains($0.typeIdentifier) })?.data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    public var kind: ClipKind {
        if !files.isEmpty { return .file }
        if representations.contains(where: Self.isImageRepresentation) { return .image }
        let text = plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.hasPrefix("#") && (text.count == 4 || text.count == 7) { return .color }
        if text.range(of: #"^https?://"#, options: .regularExpression) != nil { return .link }
        if text.contains("```") || text.contains("func ") || text.contains("import ") { return .code }
        return .text
    }
    public var suggestedTitle: String {
        if let file = files.first { return file.url.lastPathComponent }
        if kind == .image { return "Image" }
        guard let text = plainText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return "Content" }
        return String(text.split(whereSeparator: \.isNewline).first ?? Substring(text)).prefix(80).description
    }
    public var previewText: String { String((plainText ?? suggestedTitle).prefix(240)) }
    public var byteCount: Int {
        let representationBytes = representations.reduce(0) { $0 + $1.data.count }
        let importedFileBytes = files.reduce(0) { $0 + max(0, $1.byteCount ?? 0) }
        return representationBytes + importedFileBytes
    }
    public var fingerprint: String {
        // Stream FNV-1a over ordered type/data and file identities to avoid copying large payloads.
        var hash: UInt64 = 14_695_981_039_346_656_037
        func consume<S: Sequence>(_ bytes: S) where S.Element == UInt8 {
            for byte in bytes {
                hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
            }
        }
        for representation in representations {
            consume(representation.typeIdentifier.utf8)
            consume([0])
            consume(representation.data)
            consume([255])
        }
        for file in files {
            consume(file.url.absoluteString.utf8)
            consume([file.isOwnedCopy ? 1 : 0])
            if let fileByteCount = file.byteCount {
                let bigEndianByteCount = UInt64(max(0, fileByteCount)).bigEndian
                for shift in stride(from: 56, through: 0, by: -8) {
                    consume([UInt8(truncatingIfNeeded: bigEndianByteCount >> shift)])
                }
            }
        }
        return String(format: "%016llx", hash)
    }

    private static func isImageRepresentation(_ representation: ClipRepresentation) -> Bool {
        let identifier = representation.typeIdentifier.lowercased()
        let commonImageTypes: Set<String> = [
            "public.image", "public.png", "public.jpeg", "public.jpeg-2000", "public.tiff",
            "public.gif", "public.heic", "public.heif", "public.svg-image", "public.bmp",
            "com.microsoft.bmp", "com.apple.icns", "org.webmproject.webp", "public.webp"
        ]
        return commonImageTypes.contains(identifier) || identifier.contains("image")
    }
}

import AppKit
import XCTest
import MurinookDomain
import MurinookUseCases
@testable import MurinookMacIntegration

@MainActor
final class ContentItemProviderFactoryTests: XCTestCase {
    func testProviderLoadsExactStoredRepresentationOnlyWhenRequested() async throws {
        let id = UUID()
        let payload = Data([0, 255, 1, 128])
        let repository = ProviderTestRepository(content: ClipContent(representations: [
            ClipRepresentation(typeIdentifier: "public.utf8-plain-text", data: payload),
            ClipRepresentation(typeIdentifier: "public.rtf", data: Data("{\\rtf1 x}".utf8))
        ]))
        let provider = ContentItemProviderFactory().makeProvider(contentID: id, kind: .text, contents: repository)

        XCTAssertEqual(repository.readCount, 0)
        XCTAssertTrue(provider.registeredTypeIdentifiers.contains("public.utf8-plain-text"))
        let actual = try await load(provider, typeIdentifier: "public.utf8-plain-text")

        XCTAssertEqual(actual, payload)
        XCTAssertEqual(repository.readCount, 1)
    }

    func testFileProviderExportsOriginalReferenceWithoutTransferCopy() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookProviderReference-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("document.docx")
        try Data([80, 75, 3, 4]).write(to: source)
        let content = ClipContent(files: [.init(url: source, bookmark: try BookmarkAdapter().createBookmark(for: source))])
        let provider = ContentItemProviderFactory().makeProvider(for: content)
        let data = try await load(provider, typeIdentifier: "public.file-url")
        let actual = try XCTUnwrap(String(data: data, encoding: .utf8).flatMap(URL.init(string:)))
        XCTAssertEqual(actual.resolvingSymlinksInPath(), source.resolvingSymlinksInPath())
        XCTAssertFalse(provider.registeredTypeIdentifiers.contains(ContentItemProviderFactory.ownedFileTransferType))
    }

    private func load(_ provider: NSItemProvider, typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error { continuation.resume(throwing: error) }
                else if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: CocoaError(.fileReadUnknown)) }
            }
        }
    }
}

@MainActor
private final class ProviderTestRepository: ContentRepository {
    private let content: ClipContent
    private(set) var readCount = 0

    init(content: ClipContent) { self.content = content }
    func put(_ content: ClipContent, id: UUID) async throws {}
    func get(_ id: UUID) async throws -> ClipContent { readCount += 1; return content }
    func remove(_ ids: Set<UUID>) async throws {}
}

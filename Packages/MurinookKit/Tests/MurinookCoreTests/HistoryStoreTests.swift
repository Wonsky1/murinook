import XCTest
import MurinookDomain
import MurinookUseCases

@MainActor
final class HistoryStoreTests: XCTestCase {
    func testHistoryRetainsContentIconAfterReload() async throws {
        let store = HistoryStore(history: MemoryHistoryRepository(), collections: MemoryCollectionRepository(), contents: MemoryContentRepository(), preferences: PreferencesStore(repository: MemoryPreferencesRepository()))
        await store.load()
        let content = ClipContent(files: [FileReference(url: URL(fileURLWithPath: "/tmp/example.docx"))])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(content)) as? [String: Any])
        let icon = Data([1, 2, 3]).base64EncodedString()
        json["iconData"] = icon
        await store.capture(try JSONDecoder().decode(ClipContent.self, from: JSONSerialization.data(withJSONObject: json)), source: .init(name: "Finder"))
        await store.load()
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(store.clips[0])) as? [String: Any])
        XCTAssertEqual(saved["iconData"] as? String, icon)
    }


    func testDuplicateCapturePreservesIdentityAndAnnotationsWhileUpdatingCopyTime() async {
        let history = MemoryHistoryRepository()
        let collections = MemoryCollectionRepository()
        let content = MemoryContentRepository()
        let preferences = PreferencesStore(repository: MemoryPreferencesRepository())
        let store = HistoryStore(history: history, collections: collections, contents: content, preferences: preferences)
        await store.load()
        let payload = ClipContent(representations: [.init(typeIdentifier: "public.utf8-plain-text", data: Data("hello".utf8))])
        await store.capture(payload, source: .init(name: "Notes"))
        let first = try! XCTUnwrap(store.clips.first)
        var annotated = first
        annotated.isPinned = true
        annotated.note = "keep"
        await store.update(annotated)
        await store.capture(payload, source: .init(name: "Safari"))
        XCTAssertEqual(store.clips.count, 1)
        XCTAssertEqual(store.clips[0].id, first.id)
        XCTAssertTrue(store.clips[0].isPinned)
        XCTAssertEqual(store.clips[0].note, "keep")
        XCTAssertEqual(store.clips[0].source.name, "Safari")
    }

    func testRetentionRemovesOldUnpinnedButKeepsPinned() async throws {
        let history = MemoryHistoryRepository()
        let content = MemoryContentRepository()
        let preferences = PreferencesStore(repository: MemoryPreferencesRepository(value: .init(retentionDays: 1)))
        let store = HistoryStore(history: history, collections: MemoryCollectionRepository(), contents: content, preferences: preferences)
        let now = Date(timeIntervalSince1970: 2_000_000)
        let old = Date(timeIntervalSince1970: 1_000_000)
        let stale = Clip(contentID: UUID(), kind: .text, source: .init(name: "A"), createdAt: old, lastCopiedAt: old)
        let pinned = Clip(contentID: UUID(), kind: .text, source: .init(name: "A"), createdAt: old, lastCopiedAt: old, isPinned: true)
        try await history.save([stale, pinned])
        await store.load()
        await store.enforceRetention(now: now)
        XCTAssertEqual(store.clips.map(\.id), [pinned.id])
    }

    func testNeverRetentionKeepsOldUnpinnedClips() async throws {
        let history = MemoryHistoryRepository()
        let preferences = PreferencesStore(repository: MemoryPreferencesRepository(value: .init(retentionDays: 0)))
        let store = HistoryStore(history: history, collections: MemoryCollectionRepository(), contents: MemoryContentRepository(), preferences: preferences)
        let oldDate = Date(timeIntervalSince1970: 1_000_000)
        let old = Clip(contentID: UUID(), kind: .text, source: .init(name: "A"), createdAt: oldDate, lastCopiedAt: oldDate)
        try await history.save([old])
        await store.load()
        await store.enforceRetention(now: Date())
        XCTAssertEqual(store.clips, [old])
    }

    func testFailedRemovalDoesNotPublishUncommittedState() async {
        let history = MemoryHistoryRepository()
        let item = Clip(contentID: UUID(), kind: .text, source: .init(name: "A"))
        history.clips = [item]
        let store = HistoryStore(history: history, collections: MemoryCollectionRepository(), contents: MemoryContentRepository(), preferences: PreferencesStore(repository: MemoryPreferencesRepository()))
        await store.load()
        history.shouldFail = true
        await store.remove([item.id])
        XCTAssertEqual(store.clips, [item])
        XCTAssertNotNil(store.error)
    }

    func testUndoRemovalMergesDuplicateRecaptureIntoOriginalIdentityAndMetadata() async {
        let store = HistoryStore(history: MemoryHistoryRepository(), collections: MemoryCollectionRepository(), contents: MemoryContentRepository(), preferences: PreferencesStore(repository: MemoryPreferencesRepository()))
        await store.load()
        let payload = ClipContent(representations: [.init(typeIdentifier: "public.utf8-plain-text", data: Data("keep me".utf8))])
        await store.capture(payload, source: .init(name: "Notes"))
        var original = try! XCTUnwrap(store.clips.first)
        original.isPinned = true
        original.note = "important"
        await store.update(original)
        await store.remove([original.id])
        XCTAssertEqual(store.retainedContentIDs, [original.contentID])
        await store.capture(payload, source: .init(name: "Safari"))
        let recapturedAt = try! XCTUnwrap(store.clips.first?.lastCopiedAt)
        await store.undoRemoval()
        XCTAssertEqual(store.clips.count, 1)
        XCTAssertEqual(store.clips[0].id, original.id)
        XCTAssertTrue(store.clips[0].isPinned)
        XCTAssertEqual(store.clips[0].note, "important")
        XCTAssertEqual(store.clips[0].source.name, "Safari")
        XCTAssertEqual(store.clips[0].lastCopiedAt, recapturedAt)
    }

    func testCollectionRemovalRollsBackHistoryWhenCollectionSaveFails() async throws {
        let history = MemoryHistoryRepository()
        let collectionRepository = MemoryCollectionRepository()
        let collection = ClipCollection(name: "Work")
        let clip = Clip(contentID: UUID(), kind: .text, source: .init(name: "Notes"), collectionIDs: [collection.id])
        try await history.save([clip])
        try await collectionRepository.save([collection])
        let store = HistoryStore(history: history, collections: collectionRepository, contents: MemoryContentRepository(), preferences: PreferencesStore(repository: MemoryPreferencesRepository()))
        await store.load()
        collectionRepository.failNextSave = true
        await store.removeCollection(collection.id)
        XCTAssertEqual(store.clips, [clip])
        XCTAssertEqual(store.collections, [collection])
        let storedClips = try await history.load()
        let storedCollections = try await collectionRepository.load()
        XCTAssertEqual(storedClips, [clip])
        XCTAssertEqual(storedCollections, [collection])
    }

    func testFailedLoadPreventsCaptureFromOverwritingStoredHistory() async throws {
        let history = MemoryHistoryRepository()
        let existing = Clip(contentID: UUID(), kind: .text, source: .init(name: "Existing"))
        try await history.save([existing])
        history.shouldFailLoad = true
        let store = HistoryStore(history: history, collections: MemoryCollectionRepository(), contents: MemoryContentRepository(), preferences: PreferencesStore(repository: MemoryPreferencesRepository()))
        await store.load()
        await store.capture(ClipContent(representations: [.init(typeIdentifier: "public.utf8-plain-text", data: Data("new".utf8))]), source: .init(name: "Notes"))
        XCTAssertFalse(store.isLoaded)
        history.shouldFailLoad = false
        let persisted = try await history.load()
        XCTAssertEqual(persisted, [existing])
    }
}

@MainActor
private final class MemoryHistoryRepository: HistoryRepository {
    var clips: [Clip] = []
    var shouldFail = false
    var shouldFailLoad = false
    func load() async throws -> [Clip] { if shouldFailLoad { throw CocoaError(.fileReadCorruptFile) }; return clips }
    func save(_ clips: [Clip]) async throws { if shouldFail { throw CocoaError(.fileWriteUnknown) }; self.clips = clips }
}
@MainActor
private final class MemoryCollectionRepository: CollectionRepository {
    var values: [ClipCollection] = []
    var failNextSave = false
    func load() async throws -> [ClipCollection] { values }
    func save(_ values: [ClipCollection]) async throws {
        if failNextSave { failNextSave = false; throw CocoaError(.fileWriteUnknown) }
        self.values = values
    }
}
@MainActor
private final class MemoryContentRepository: ContentRepository {
    var values: [UUID: ClipContent] = [:]
    func put(_ content: ClipContent, id: UUID) async throws { values[id] = content }
    func get(_ id: UUID) async throws -> ClipContent { guard let value = values[id] else { throw CocoaError(.fileNoSuchFile) }; return value }
    func remove(_ ids: Set<UUID>) async throws { ids.forEach { values.removeValue(forKey: $0) } }
}
@MainActor
private final class MemoryPreferencesRepository: PreferencesRepository {
    var value: AppPreferences
    init(value: AppPreferences = .init()) { self.value = value }
    func load() -> AppPreferences { value }
    func save(_ value: AppPreferences) throws { self.value = value }
}

import XCTest
import MurinookDomain
import MurinookUseCases

@MainActor
final class ShelfStoreTests: XCTestCase {
    func testShelfRetainsPerFileIconsAfterReload() async throws {
        let repository = MemoryShelfRepository()
        let contents = MemoryContentRepository()
        let store = ShelfStore(repository: repository, contents: contents)
        await store.load()
        let file = FileReference(url: URL(fileURLWithPath: "/tmp/example.docx"))
        let content = ClipContent(files: [file])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(content)) as? [String: Any])
        var files = try XCTUnwrap(json["files"] as? [[String: Any]])
        let icon = Data([1, 2, 3]).base64EncodedString()
        files[0]["iconData"] = icon
        json["files"] = files
        await store.add(content: try JSONDecoder().decode(ClipContent.self, from: JSONSerialization.data(withJSONObject: json)))
        await store.load()
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(store.items[0])) as? [String: Any])
        XCTAssertEqual(saved["iconData"] as? String, icon)
    }


    func testMoveDownUsesFinalIndexAndPersistsOrder() async {
        let repository = MemoryShelfRepository()
        let first = ShelfItem(contentID: UUID(), title: "First", kind: .text)
        let second = ShelfItem(contentID: UUID(), title: "Second", kind: .text)
        repository.values = [first, second]
        let store = ShelfStore(repository: repository, contents: MemoryContentRepository())
        await store.load()
        await store.move(from: 0, to: 1)
        XCTAssertEqual(store.items.map(\.title), ["Second", "First"])
        XCTAssertEqual(repository.values, store.items)
    }

    func testUndoRestoresOnlyMostRecentlyRemovedBatch() async throws {
        let repository = MemoryShelfRepository()
        let store = ShelfStore(repository: repository, contents: MemoryContentRepository())
        let one = ShelfItem(contentID: UUID(), title: "One", kind: .file)
        let two = ShelfItem(contentID: UUID(), title: "Two", kind: .image)
        try await repository.save([one, two])
        await store.load()
        await store.remove([one.id])
        await store.remove([two.id])
        await store.undoRemoval()
        XCTAssertEqual(store.items.map(\.id), [two.id])
        await store.undoRemoval()
        XCTAssertEqual(store.items.map(\.id), [two.id])
    }

    func testFailedRemovalKeepsPublishedItemsAndUndoHistory() async {
        let repository = MemoryShelfRepository()
        let item = ShelfItem(contentID: UUID(), title: "One", kind: .file)
        repository.values = [item]
        let store = ShelfStore(repository: repository, contents: MemoryContentRepository())
        await store.load()
        repository.shouldFail = true
        await store.remove([item.id])
        XCTAssertEqual(store.items, [item])
        XCTAssertNotNil(store.error)
    }

    func testLegacyShelfItemDecodesUnlocked() throws {
        let item = ShelfItem(contentID: UUID(), title: "Old item", kind: .file)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        object.removeValue(forKey: "isLocked")

        let restored = try JSONDecoder().decode(ShelfItem.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(restored.isLocked)
        XCTAssertEqual(restored.id, item.id)
        XCTAssertEqual(restored.contentID, item.contentID)
    }

    func testLockChangePersistsAndFailedSaveKeepsPublishedValue() async throws {
        let repository = MemoryShelfRepository()
        let item = ShelfItem(contentID: UUID(), title: "One", kind: .file)
        repository.values = [item]
        let store = ShelfStore(repository: repository, contents: MemoryContentRepository())
        await store.load()

        await store.setLocked(true, for: item.id)
        XCTAssertTrue(try XCTUnwrap(repository.values.first).isLocked)
        XCTAssertTrue(try XCTUnwrap(store.items.first).isLocked)

        repository.shouldFail = true
        await store.setLocked(false, for: item.id)
        XCTAssertTrue(try XCTUnwrap(store.items.first).isLocked)
        XCTAssertNotNil(store.error)
    }

    func testTransferRemovesOnlyUnlockedItemsInTheCurrentStoreState() async throws {
        let repository = MemoryShelfRepository()
        let unlocked = ShelfItem(contentID: UUID(), title: "Remove", kind: .file)
        let locked = ShelfItem(contentID: UUID(), title: "Keep", kind: .image)
        repository.values = [unlocked, locked]
        let store = ShelfStore(repository: repository, contents: MemoryContentRepository())
        await store.load()
        await store.setLocked(true, for: locked.id)

        await store.completeTransfer([unlocked.id, locked.id])

        var expectedLocked = locked
        expectedLocked.isLocked = true
        XCTAssertEqual(store.items, [expectedLocked])
        XCTAssertEqual(repository.values, [expectedLocked])
        XCTAssertEqual(store.retainedContentIDs, [locked.contentID])
    }

    func testUndoRestoresLockAndUnlockAllowsLaterTransferRemoval() async throws {
        let repository = MemoryShelfRepository()
        var locked = ShelfItem(contentID: UUID(), title: "Keep", kind: .file)
        locked.isLocked = true
        repository.values = [locked]
        let store = ShelfStore(repository: repository, contents: MemoryContentRepository())
        await store.load()

        await store.remove([locked.id])
        await store.undoRemoval()
        XCTAssertTrue(try XCTUnwrap(store.items.first).isLocked)

        await store.setLocked(false, for: locked.id)
        await store.completeTransfer([locked.id])
        XCTAssertTrue(store.items.isEmpty)
    }

    func testFailedLoadPreventsShelfMutationFromOverwritingStoredItems() async throws {
        let repository = MemoryShelfRepository()
        let existing = ShelfItem(contentID: UUID(), title: "Existing", kind: .file)
        repository.values = [existing]
        repository.shouldFailLoad = true
        let store = ShelfStore(repository: repository, contents: MemoryContentRepository())
        await store.load()
        await store.add(contentID: UUID(), title: "New", kind: .text)
        XCTAssertFalse(store.isLoaded)
        repository.shouldFailLoad = false
        let persisted = try await repository.load()
        XCTAssertEqual(persisted, [existing])
    }

    func testCompletedTransferRemovesPersistedItemAndUndoRetention() async throws {
        let repository = MemoryShelfRepository()
        let transferred = ShelfItem(contentID: UUID(), title: "Transferred", kind: .file)
        let retained = ShelfItem(contentID: UUID(), title: "Still here", kind: .image)
        try await repository.save([transferred, retained])
        let store = ShelfStore(repository: repository, contents: MemoryContentRepository())
        await store.load()

        await store.completeTransfer([transferred.id])

        XCTAssertEqual(store.items.map(\.id), [retained.id])
        XCTAssertEqual(repository.values.map(\.id), [retained.id])
        XCTAssertEqual(store.retainedContentIDs, [retained.contentID])
        await store.undoRemoval()
        XCTAssertEqual(store.items.map(\.id), [retained.id])
    }

    func testCompletedTransferClearsMatchingRemovedBatchReference() async throws {
        let repository = MemoryShelfRepository()
        let completed = ShelfItem(contentID: UUID(), title: "Completed", kind: .file)
        let undoable = ShelfItem(contentID: UUID(), title: "Undoable", kind: .image)
        try await repository.save([completed, undoable])
        let store = ShelfStore(repository: repository, contents: MemoryContentRepository())
        await store.load()

        await store.remove([completed.id, undoable.id])
        await store.completeTransfer([completed.id])

        XCTAssertEqual(store.retainedContentIDs, [undoable.contentID])
        await store.undoRemoval()
        XCTAssertEqual(store.items.map(\.id), [undoable.id])
    }

    func testSharedContentIDRemainsRetainedByEveryLiveStore() async throws {
        let sharedID = UUID()
        let shelfRepository = MemoryShelfRepository()
        let shelfItem = ShelfItem(contentID: sharedID, title: "Shared", kind: .file)
        try await shelfRepository.save([shelfItem])
        let shelf = ShelfStore(repository: shelfRepository, contents: MemoryContentRepository())
        await shelf.load()
        let queue = QueueStore()
        queue.add(contentID: sharedID, title: "Shared", kind: .file)

        XCTAssertTrue(shelf.retainedContentIDs.contains(sharedID))
        XCTAssertTrue(queue.retainedContentIDs.contains(sharedID))
        queue.clear()
        XCTAssertFalse(queue.retainedContentIDs.contains(sharedID))
        XCTAssertTrue(shelf.retainedContentIDs.contains(sharedID))
    }
}
@MainActor
private final class MemoryShelfRepository: ShelfRepository {
    var values: [ShelfItem] = []
    var shouldFail = false
    var shouldFailLoad = false
    func load() async throws -> [ShelfItem] { if shouldFailLoad { throw CocoaError(.fileReadCorruptFile) }; return values }
    func save(_ items: [ShelfItem]) async throws { if shouldFail { throw CocoaError(.fileWriteUnknown) }; values = items }
}
@MainActor
private final class MemoryContentRepository: ContentRepository {
    func put(_ content: ClipContent, id: UUID) async throws {}
    func get(_ id: UUID) async throws -> ClipContent { ClipContent() }
    func remove(_ ids: Set<UUID>) async throws {}
}

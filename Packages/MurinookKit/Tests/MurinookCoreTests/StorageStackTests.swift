import XCTest
import MurinookDomain
import MurinookStorage
import MurinookUseCases

@MainActor
final class StorageStackTests: XCTestCase {
    func testCorruptedPreferencesArePreservedAndFailInitialization() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookBadPreferences-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Preferences.json")
        let corruptData = Data("broken settings".utf8)
        try corruptData.write(to: url)
        XCTAssertThrowsError(try StorageStack(directory: directory))
        XCTAssertEqual(try Data(contentsOf: url), corruptData)
    }
    func testCaptureStoresFullTextMetadataAndItSurvivesRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookSearchText-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let fullText = String(repeating: "ordinary clipboard words ", count: 20) + "needle beyond the preview"
        do {
            let stack = try StorageStack(directory: directory)
            let preferences = PreferencesStore(repository: stack.preferences)
            let historyStore = HistoryStore(history: stack.history, collections: stack.collections, contents: stack.contents, preferences: preferences)
            await historyStore.load()
            await historyStore.capture(
                ClipContent(representations: [.init(typeIdentifier: "public.utf8-plain-text", data: Data(fullText.utf8))]),
                source: SourceApplication(name: "Notes")
            )
            XCTAssertEqual(historyStore.clips.first?.searchText, fullText)
            XCTAssertFalse(historyStore.clips.first?.preview.contains("needle") ?? true)
        }
        let relaunched = try StorageStack(directory: directory)
        let restored = try await relaunched.history.load()
        XCTAssertEqual(restored.first?.searchText, fullText)
        XCTAssertFalse(restored.first?.preview.contains("needle") ?? true)
    }
    func testMetadataAndPayloadSurviveFreshStackAndKeepExternalOwnership() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookCore-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let payload = ClipContent(files: [.init(url: URL(fileURLWithPath: "/tmp/original.pdf"), bookmark: Data([1, 2]), isOwnedCopy: false)])
        let contentID = UUID()
        let clip = Clip(contentID: contentID, kind: .file, source: .init(name: "Finder"), fingerprint: payload.fingerprint)
        let shelfItems = [
            ShelfItem(contentID: UUID(), title: "Earlier", kind: .file),
            ShelfItem(contentID: UUID(), title: "Moved first", kind: .image)
        ]
        do {
            let stack = try StorageStack(directory: directory)
            try await stack.contents.put(payload, id: contentID)
            try await stack.history.save([clip])
            try await stack.shelf.save(shelfItems)
        }
        let relaunched = try StorageStack(directory: directory)
        let restoredClips = try await relaunched.history.load()
        let restoredPayload = try await relaunched.contents.get(contentID)
        let restoredShelf = try await relaunched.shelf.load()
        XCTAssertEqual(restoredClips, [clip])
        XCTAssertEqual(restoredPayload, payload)
        XCTAssertFalse(restoredPayload.files[0].isOwnedCopy)
        XCTAssertEqual(restoredShelf, shelfItems)
    }

    func testTenThousandMetadataRecordsRoundTripAndRecordsMeasurement() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookMetadata-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let stack = try StorageStack(directory: directory)
        let records = (0..<10_000).map { index in
            Clip(
                contentID: UUID(),
                title: "Clip \(index)",
                preview: "Preview \(index)",
                kind: .text,
                source: SourceApplication(name: "Benchmark"),
                createdAt: Date(timeIntervalSince1970: Double(index)),
                lastCopiedAt: Date(timeIntervalSince1970: Double(index)),
                fingerprint: "fingerprint-\(index)"
            )
        }

        let started = Date()
        try await stack.history.save(records)
        let restored = try await stack.history.load()
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertEqual(restored.count, records.count)
        XCTContext.runActivity(named: "10,000 metadata round trip: \(elapsed) seconds") { activity in
            activity.add(XCTAttachment(string: "\(elapsed) seconds"))
        }
    }

    func testStartupPruningRemovesOrphanPayloadsAndOnlyUnreferencedOwnedFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookPrune-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let importedDirectory = directory.appendingPathComponent("ImportedFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: importedDirectory, withIntermediateDirectories: true)

        let orphanOwnedFile = importedDirectory.appendingPathComponent("orphan.pdf")
        let sharedOwnedFile = importedDirectory.appendingPathComponent("shared.pdf")
        let externalFile = directory.appendingPathComponent("external.pdf")
        try Data("orphan".utf8).write(to: orphanOwnedFile)
        try Data("shared".utf8).write(to: sharedOwnedFile)
        try Data("external".utf8).write(to: externalFile)

        let stack = try StorageStack(directory: directory)
        let retainedID = UUID()
        let sharedOrphanID = UUID()
        let orphanID = UUID()
        try await stack.contents.put(ClipContent(files: [
            FileReference(url: sharedOwnedFile, isOwnedCopy: true),
            FileReference(url: externalFile, isOwnedCopy: false)
        ]), id: retainedID)
        try await stack.contents.put(ClipContent(files: [
            FileReference(url: sharedOwnedFile, isOwnedCopy: true)
        ]), id: sharedOrphanID)
        try await stack.contents.put(ClipContent(files: [
            FileReference(url: orphanOwnedFile, isOwnedCopy: true)
        ]), id: orphanID)

        try await stack.pruneUnreferencedContents(retaining: [retainedID])

        let retainedContent = try await stack.contents.get(retainedID)
        XCTAssertEqual(retainedContent.files.count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sharedOwnedFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanOwnedFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalFile.path))
        do {
            _ = try await stack.contents.get(orphanID)
            XCTFail("Expected pruned payload to be missing")
        } catch { }
        do {
            _ = try await stack.contents.get(sharedOrphanID)
            XCTFail("Expected unreferenced payload to be missing")
        } catch { }
    }

    func testPruningCorruptPayloadAbortsWithoutDeletingAnyFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookPruneCorrupt-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let importedDirectory = directory.appendingPathComponent("ImportedFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: importedDirectory, withIntermediateDirectories: true)
        let ownedFile = importedDirectory.appendingPathComponent("still-needed.pdf")
        try Data("file".utf8).write(to: ownedFile)

        let stack = try StorageStack(directory: directory)
        let contentID = UUID()
        try await stack.contents.put(ClipContent(files: [FileReference(url: ownedFile, isOwnedCopy: true)]), id: contentID)
        let corruptPayload = directory.appendingPathComponent("Content", isDirectory: true)
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("payload")
        try Data("invalid payload".utf8).write(to: corruptPayload)

        do {
            try await stack.pruneUnreferencedContents(retaining: [])
            XCTFail("Expected corrupt payload to prevent pruning")
        } catch { }

        XCTAssertTrue(FileManager.default.fileExists(atPath: ownedFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptPayload.path))
        let content = try await stack.contents.get(contentID)
        XCTAssertEqual(content.files.first?.url, ownedFile)
    }

    func testPruningKeepsOrphanOwnedDirectoryWhenRetainedPayloadReferencesChild() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookPruneDirectory-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let importedDirectory = directory.appendingPathComponent("ImportedFiles", isDirectory: true)
        let ownedFolder = importedDirectory.appendingPathComponent("bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: ownedFolder, withIntermediateDirectories: true)
        let ownedChild = ownedFolder.appendingPathComponent("document.pdf")
        try Data("document".utf8).write(to: ownedChild)

        let stack = try StorageStack(directory: directory)
        let retainedID = UUID()
        let orphanID = UUID()
        try await stack.contents.put(ClipContent(files: [
            FileReference(url: ownedChild, isOwnedCopy: false)
        ]), id: retainedID)
        try await stack.contents.put(ClipContent(files: [
            FileReference(url: ownedFolder, isOwnedCopy: true)
        ]), id: orphanID)

        try await stack.pruneUnreferencedContents(retaining: [retainedID])

        XCTAssertTrue(FileManager.default.fileExists(atPath: ownedFolder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: ownedChild.path))
        do {
            _ = try await stack.contents.get(orphanID)
            XCTFail("Expected orphan payload to be pruned")
        } catch { }
    }

    func testPruningRemovesOrphanImportedItemDirectoryWithoutPayload() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookPruneNoPayload-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let importedDirectory = directory.appendingPathComponent("ImportedFiles", isDirectory: true)
        let orphanContainer = importedDirectory.appendingPathComponent("orphan-item", isDirectory: true)
        try FileManager.default.createDirectory(at: orphanContainer, withIntermediateDirectories: true)
        let orphanFile = orphanContainer.appendingPathComponent("promised.bin")
        try Data("materialized but payload write failed".utf8).write(to: orphanFile)

        let stack = try StorageStack(directory: directory)
        try await stack.pruneUnreferencedContents(retaining: [])

        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanContainer.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanFile.path))
    }

    func testPruningDoesNotFollowSymlinkOutOfImportedFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookPruneSymlink-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let importedDirectory = directory.appendingPathComponent("ImportedFiles", isDirectory: true)
        let externalDirectory = directory.appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(at: importedDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: externalDirectory, withIntermediateDirectories: true)
        let externalFile = externalDirectory.appendingPathComponent("keep.txt")
        try Data("original".utf8).write(to: externalFile)
        try FileManager.default.createSymbolicLink(at: importedDirectory.appendingPathComponent("escape", isDirectory: true), withDestinationURL: externalDirectory)

        let stack = try StorageStack(directory: directory)
        try await stack.pruneUnreferencedContents(retaining: [])

        XCTAssertTrue(FileManager.default.fileExists(atPath: externalFile.path))
    }

    func testPruningPreservesProtectedImportStagingSubtree() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookPruneProtected-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let importedDirectory = directory.appendingPathComponent("ImportedFiles", isDirectory: true)
        let stagingDirectory = importedDirectory.appendingPathComponent(".promise-123", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let stagingFile = stagingDirectory.appendingPathComponent("received.dat")
        try Data("in flight".utf8).write(to: stagingFile)

        let stack = try StorageStack(directory: directory)
        try await stack.pruneUnreferencedContents(retaining: [], protectedImportURLs: [stagingDirectory])

        XCTAssertTrue(FileManager.default.fileExists(atPath: stagingFile.path))
    }

    func testPruningRemovesOrphanPayloadWhenImportedFilesDirectoryIsMissing() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookPruneMissingImports-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let stack = try StorageStack(directory: directory)
        let orphanID = UUID()
        try await stack.contents.put(ClipContent(representations: [
            .init(typeIdentifier: "public.utf8-plain-text", data: Data("orphan".utf8))
        ]), id: orphanID)

        try await stack.pruneUnreferencedContents(retaining: [])

        do {
            _ = try await stack.contents.get(orphanID)
            XCTFail("Expected orphan payload to be pruned even without ImportedFiles")
        } catch { }
    }

    func testPruningRemovesUnreferencedSiblingInsideRetainedContainer() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookPruneSibling-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let importedDirectory = directory.appendingPathComponent("ImportedFiles", isDirectory: true)
        let itemDirectory = importedDirectory.appendingPathComponent("item-1", isDirectory: true)
        try FileManager.default.createDirectory(at: itemDirectory, withIntermediateDirectories: true)
        let retainedFile = itemDirectory.appendingPathComponent("retained.txt")
        let orphanSibling = itemDirectory.appendingPathComponent("orphan.txt")
        try Data("retained".utf8).write(to: retainedFile)
        try Data("orphan".utf8).write(to: orphanSibling)

        let stack = try StorageStack(directory: directory)
        let retainedID = UUID()
        try await stack.contents.put(ClipContent(files: [FileReference(url: retainedFile, isOwnedCopy: true)]), id: retainedID)

        try await stack.pruneUnreferencedContents(retaining: [retainedID])

        XCTAssertTrue(FileManager.default.fileExists(atPath: retainedFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanSibling.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: itemDirectory.path))
    }

    func testCorruptedMetadataStoreFailsInsteadOfOpeningEmpty() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MurinookCorrupt-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not a SwiftData store".utf8).write(to: directory.appendingPathComponent("Metadata.store"))
        XCTAssertThrowsError(try StorageStack(directory: directory))
    }
}

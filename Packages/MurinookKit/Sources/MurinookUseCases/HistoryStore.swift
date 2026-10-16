import Foundation
import Observation
import MurinookDomain

@MainActor @Observable public final class HistoryStore {
    public private(set) var clips: [Clip] = []
    public private(set) var collections: [ClipCollection] = []
    public private(set) var errorMessage: String?
    public private(set) var error: UseCaseError?
    public private(set) var isLoaded = false
    public var retainedContentIDs: Set<UUID> {
        Set((clips + removedBatch).map(\.contentID))
    }

    private let historyRepository: any HistoryRepository
    private let collectionRepository: any CollectionRepository
    private let contents: any ContentRepository
    private let preferences: PreferencesStore
    private let mutations: SerializedMutationQueue
    private var removedBatch: [Clip] = []
    private var removedAt = 0

    public init(
        history: any HistoryRepository,
        collections: any CollectionRepository,
        contents: any ContentRepository,
        preferences: PreferencesStore,
        accessGate: ContentAccessGate? = nil
    ) {
        historyRepository = history
        collectionRepository = collections
        self.contents = contents
        self.preferences = preferences
        mutations = SerializedMutationQueue(accessGate: accessGate)
    }

    public func load() async {
        await mutations.run { [weak self] in
            guard let self else { return }
            isLoaded = false
            do {
                let loadedClips = try await historyRepository.load()
                let loadedCollections = try await collectionRepository.load()
                clips = Self.sorted(loadedClips)
                collections = loadedCollections
                isLoaded = true
                clearError()
            } catch {
                report("history.load")
            }
        }
    }

    public func capture(_ content: ClipContent, source: SourceApplication) async {
        guard preferences.value.captureEnabled else { return }
        await mutations.run { [weak self] in
            guard let self, requireLoaded() else { return }
            do {
                let now = Date()
                if let existingIndex = clips.firstIndex(where: { $0.fingerprint == content.fingerprint }) {
                    var updated = clips[existingIndex]
                    updated.lastCopiedAt = now
                    updated.source = source
                    updated.iconData = content.iconData ?? updated.iconData
                    var proposed = clips
                    proposed[existingIndex] = updated
                    try await historyRepository.save(Self.sorted(proposed))
                    clips = Self.sorted(proposed)
                } else {
                    let contentID = UUID()
                    try await contents.put(content, id: contentID)
                    let newClip = Clip(
                        contentID: contentID,
                        title: content.suggestedTitle,
                        preview: content.previewText,
                        searchText: content.plainText,
                        kind: content.kind,
                        source: source,
                        createdAt: now,
                        byteCount: content.byteCount,
                        fingerprint: content.fingerprint,
                        iconData: content.iconData
                    )
                    let proposed = HistoryRetentionPolicy.apply(
                        [newClip] + clips,
                        preferences: preferences.value,
                        now: now
                    )
                    try await historyRepository.save(proposed)
                    clips = proposed
                }
                clearError()
            } catch {
                report("history.capture")
            }
        }
    }

    public func setIconData(_ data: Data, for id: UUID) async {
        await changeClip(id) { $0.iconData = data }
    }

    public func togglePin(_ id: UUID) async {
        await changeClip(id) { $0.isPinned.toggle() }
    }

    public func updateDetails(_ id: UUID, note: String, tags: [String]) async {
        await changeClip(id) { clip in
            clip.note = note
            clip.tags = tags
        }
    }

    public func update(_ clip: Clip) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded(), let index = clips.firstIndex(where: { $0.id == clip.id }) else { return }
            var proposed = clips
            proposed[index] = clip
            _ = await commitClips(proposed, key: "history.update")
        }
    }

    public func remove(_ ids: Set<UUID>) async {
        await removeItems(ids)
    }

    public func undoRemoval() async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded(), !removedBatch.isEmpty else { return }
            let fingerprints = Set(removedBatch.map(\.fingerprint).filter { !$0.isEmpty })
            let recaptured = Dictionary(
                clips.filter { !$0.fingerprint.isEmpty }.map { ($0.fingerprint, $0) },
                uniquingKeysWith: { current, _ in current }
            )
            var proposed = clips.filter { !fingerprints.contains($0.fingerprint) }
            let restored = removedBatch.map { self.mergeRecapture($0, with: recaptured[$0.fingerprint]) }
            proposed.insert(contentsOf: restored, at: min(removedAt, proposed.count))
            if await commitClips(proposed, key: "history.undo") {
                removedBatch = []
            }
        }
    }

    public func clearUnpinned() async {
        await removeItems(Set(clips.filter { !$0.isPinned }.map(\.id)))
    }

    public func addCollection(name: String, colorHex: String) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded() else { return }
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let proposed = collections + [ClipCollection(name: trimmedName, colorHex: colorHex)]
            await commitCollections(proposed, key: "collections.add")
        }
    }

    public func renameCollection(_ id: UUID, name: String) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded(), let index = collections.firstIndex(where: { $0.id == id }) else { return }
            var proposed = collections
            proposed[index].name = name
            await commitCollections(proposed, key: "collections.rename")
        }
    }

    public func removeCollection(_ id: UUID) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded() else { return }
            let oldClips = clips
            let oldCollections = collections
            let newClips = clips.map { clip -> Clip in
                var updated = clip
                updated.collectionIDs.remove(id)
                return updated
            }
            let newCollections = collections.filter { $0.id != id }

            do {
                try await historyRepository.save(newClips)
            } catch {
                report("collections.remove")
                return
            }
            do {
                try await collectionRepository.save(newCollections)
            } catch {
                do {
                    try await restoreAfterCollectionFailure(clips: oldClips, collections: oldCollections)
                } catch {
                    report("collections.remove.rollbackFailed")
                    return
                }
                report("collections.remove")
                return
            }
            clips = newClips
            collections = newCollections
            clearError()
        }
    }

    public func setCollection(_ ids: Set<UUID>, collectionID: UUID, included: Bool) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded() else { return }
            var proposed = clips
            for index in proposed.indices where ids.contains(proposed[index].id) {
                if included {
                    proposed[index].collectionIDs.insert(collectionID)
                } else {
                    proposed[index].collectionIDs.remove(collectionID)
                }
            }
            _ = await commitClips(proposed, key: "collections.membership")
        }
    }

    public func enforceRetention(now: Date) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded() else { return }
            let proposed = HistoryRetentionPolicy.apply(clips, preferences: preferences.value, now: now)
            _ = await commitClips(proposed, key: "history.retention")
        }
    }

    private func removeItems(_ ids: Set<UUID>) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded() else { return }
            let indexedItems = clips.enumerated().filter { ids.contains($0.element.id) }
            guard !indexedItems.isEmpty else { return }

            let proposed = clips.filter { !ids.contains($0.id) }
            do {
                try await historyRepository.save(proposed)
                removedBatch = indexedItems.map(\.element)
                removedAt = indexedItems.first?.offset ?? 0
                clips = Self.sorted(proposed)
                clearError()
            } catch {
                report("history.remove")
            }
        }
    }

    private func changeClip(_ id: UUID, change: @escaping (inout Clip) -> Void) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded(), let index = clips.firstIndex(where: { $0.id == id }) else { return }
            var proposed = clips
            change(&proposed[index])
            _ = await commitClips(proposed, key: "history.update")
        }
    }

    private func commitClips(_ proposed: [Clip], key: String) async -> Bool {
        do {
            let sortedClips = Self.sorted(proposed)
            try await historyRepository.save(sortedClips)
            clips = sortedClips
            clearError()
            return true
        } catch {
            report(key)
            return false
        }
    }

    private func commitCollections(_ proposed: [ClipCollection], key: String) async {
        do {
            try await collectionRepository.save(proposed)
            collections = proposed
            clearError()
        } catch {
            report(key)
        }
    }

    private func restoreAfterCollectionFailure(clips oldClips: [Clip], collections oldCollections: [ClipCollection]) async throws {
        try await historyRepository.save(oldClips)
        try await collectionRepository.save(oldCollections)
    }

    private func mergeRecapture(_ removed: Clip, with recaptured: Clip?) -> Clip {
        guard let recaptured, !removed.fingerprint.isEmpty else { return removed }
        var merged = removed
        merged.lastCopiedAt = max(removed.lastCopiedAt, recaptured.lastCopiedAt)
        merged.source = recaptured.source
        return merged
    }

    private func report(_ key: String) {
        error = .persistence(operation: key)
        errorMessage = "A change could not be saved."
    }

    private func requireLoaded() -> Bool {
        guard isLoaded else {
            report("storage.notLoaded")
            return false
        }
        return true
    }

    private func clearError() {
        error = nil
        errorMessage = nil
    }

    private static func sorted(_ clips: [Clip]) -> [Clip] {
        clips.sorted { $0.lastCopiedAt > $1.lastCopiedAt }
    }
}

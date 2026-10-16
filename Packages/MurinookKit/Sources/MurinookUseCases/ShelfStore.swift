import Foundation
import Observation
import MurinookDomain

@MainActor @Observable public final class ShelfStore {
    public private(set) var items: [ShelfItem] = []
    public private(set) var errorMessage: String?
    public private(set) var error: UseCaseError?
    public private(set) var isLoaded = false
    public var retainedContentIDs: Set<UUID> {
        Set((items + removedBatch).map(\.contentID))
    }

    private let repository: any ShelfRepository
    private let contents: any ContentRepository
    private let mutations: SerializedMutationQueue
    private var removedBatch: [ShelfItem] = []
    private var removedAt = 0

    public init(repository: any ShelfRepository, contents: any ContentRepository, accessGate: ContentAccessGate? = nil) {
        self.repository = repository
        self.contents = contents
        mutations = SerializedMutationQueue(accessGate: accessGate)
    }

    public func load() async {
        await mutations.run { [weak self] in
            guard let self else { return }
            isLoaded = false
            do {
                items = try await repository.load()
                isLoaded = true
                clearError()
            } catch {
                report("shelf.load")
            }
        }
    }

    public func add(content: ClipContent) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded() else { return }
            do {
                var proposed = items
                if content.files.isEmpty {
                    let contentID = UUID()
                    try await contents.put(content, id: contentID)
                    proposed.append(ShelfItem(contentID: contentID, title: content.suggestedTitle, kind: content.kind, iconData: content.iconData))
                } else {
                    for file in content.files {
                        let contentID = UUID()
                        try await contents.put(ClipContent(representations: content.representations, files: [file], iconData: file.iconData ?? content.iconData), id: contentID)
                        proposed.append(ShelfItem(contentID: contentID, title: file.url.lastPathComponent, kind: .file, iconData: file.iconData ?? content.iconData))
                    }
                }
                await commit(proposed, key: "shelf.add")
            } catch {
                report("shelf.add")
            }
        }
    }

    public func add(contentID: UUID, title: String, kind: ClipKind, iconData: Data? = nil) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded() else { return }
            await commit(items + [ShelfItem(contentID: contentID, title: title, kind: kind, iconData: iconData)], key: "shelf.add")
        }
    }

    public func setIconData(_ data: Data, for id: UUID) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded(), let index = items.firstIndex(where: { $0.id == id }) else { return }
            var proposed = items
            proposed[index].iconData = data
            await commit(proposed, key: "shelf.update")
        }
    }

    public func remove(_ ids: Set<UUID>) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded() else { return }
            let selectedItems = items.enumerated().filter { ids.contains($0.element.id) }
            guard !selectedItems.isEmpty else { return }
            let proposed = items.filter { !ids.contains($0.id) }
            do {
                try await repository.save(proposed)
                items = proposed
                removedBatch = selectedItems.map(\.element)
                removedAt = selectedItems.first?.offset ?? 0
                clearError()
            } catch {
                report("shelf.remove")
            }
        }
    }

    /// Removes successfully transferred live items without creating an undo batch.
    /// Matching items in the current undo batch are also released because the destination
    /// now owns their transfer outcome and restoring them would resurrect completed work.
    public func completeTransfer(_ itemIDs: Set<UUID>) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded(), !itemIDs.isEmpty else { return }
            let proposed = items.filter { !itemIDs.contains($0.id) }
            if proposed.count != items.count, !(await commit(proposed, key: "shelf.transfer")) {
                return
            }
            removedBatch.removeAll { itemIDs.contains($0.id) }
        }
    }

    public func clear() async {
        await remove(Set(items.map(\.id)))
    }

    public func undoRemoval() async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded(), !removedBatch.isEmpty else { return }
            var proposed = items
            proposed.insert(contentsOf: removedBatch, at: min(removedAt, proposed.count))
            if await commit(proposed, key: "shelf.undo") {
                removedBatch = []
            }
        }
    }

    public func move(from sourceIndex: Int, to destinationIndex: Int) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded(), items.indices.contains(sourceIndex), (0...items.count).contains(destinationIndex), sourceIndex != destinationIndex else { return }
            var proposed = items
            let movedItem = proposed.remove(at: sourceIndex)
            let adjustedIndex = destinationIndex
            proposed.insert(movedItem, at: min(adjustedIndex, proposed.count))
            _ = await commit(proposed, key: "shelf.move")
        }
    }

    public func group(_ ids: Set<UUID>) async {
        await setGroup(ids, to: UUID())
    }

    public func ungroup(_ ids: Set<UUID>) async {
        await setGroup(ids, to: nil)
    }

    private func setGroup(_ ids: Set<UUID>, to groupID: UUID?) async {
        await mutations.run { [weak self] in
            guard let self, requireLoaded() else { return }
            var proposed = items
            for index in proposed.indices where ids.contains(proposed[index].id) {
                proposed[index].groupID = groupID
            }
            _ = await commit(proposed, key: "shelf.group")
        }
    }

    @discardableResult private func commit(_ proposed: [ShelfItem], key: String) async -> Bool {
        do {
            try await repository.save(proposed)
            items = proposed
            clearError()
            return true
        } catch {
            report(key)
            return false
        }
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
}

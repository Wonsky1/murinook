import Foundation
import MurinookDomain
import MurinookUseCases
import MurinookStorage
import MurinookMacIntegration

/// Upgrades existing metadata without changing content identity or copy timestamps.
final class ContentVisualBackfill {
    private let services: ApplicationServices
    private var task: Task<Void, Never>?

    init(services: ApplicationServices) { self.services = services }

    func start() {
        task = Task {
            for clip in services.history.clips where clip.iconData == nil && [.file, .image].contains(clip.kind) {
                guard !Task.isCancelled else { return }
                if let icon = await decorate(clip.contentID) { await services.history.setIconData(icon, for: clip.id) }
            }
            for item in services.shelf.items where item.iconData == nil && [.file, .image].contains(item.kind) {
                guard !Task.isCancelled else { return }
                if let icon = await decorate(item.contentID) { await services.shelf.setIconData(icon, for: item.id) }
            }
        }
    }

    func stop() { task?.cancel(); task = nil }

    private func decorate(_ id: UUID) async -> Data? {
        do {
            return try await services.contentAccess.withAccess {
                let content = try await services.storage.contents.get(id)
                let decorated = await services.visuals.addingVisuals(to: content)
                guard let icon = decorated.iconData else { return nil }
                if decorated != content { try await services.storage.contents.put(decorated, id: id) }
                return icon
            }
        } catch { return nil } // A missing external file must not prevent startup.
    }
}

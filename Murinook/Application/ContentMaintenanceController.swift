import Foundation
import MurinookUseCases
import MurinookStorage
import Observation
import OSLog

/// Reclaims only unreachable content, after writers and active transfers finish.
final class ContentMaintenanceController {
    private let services: ApplicationServices
    private var task: Task<Void, Never>?
    private var previousIDs = Set<UUID>()
    private var needsSweep = false
    private var isRunning = false
    private var retryTimer: Timer?
    private let logger = Logger(subsystem: "wonsky.Murinook", category: "ContentMaintenance")

    init(services: ApplicationServices) { self.services = services }

    private var retainedIDs: Set<UUID> {
        services.history.retainedContentIDs
            .union(services.shelf.retainedContentIDs)
            .union(services.queue.retainedContentIDs)
    }

    func start() {
        isRunning = true
        previousIDs = retainedIDs
        observeReferences()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.request() }
        }
        request()
    }

    func stop() { isRunning = false; retryTimer?.invalidate(); retryTimer = nil; task?.cancel(); task = nil }

    func request() {
        guard isRunning else { return }
        needsSweep = true
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            while needsSweep && !Task.isCancelled {
                needsSweep = false
                do {
                    try await services.contentAccess.withMaintenance {
                        guard !Task.isCancelled else { return }
                        // Snapshot after acquiring exclusivity, not when deletion was requested.
                        try await services.storage.pruneUnreferencedContents(retaining: retainedIDs)
                    }
                } catch {
                    logger.error("Content cleanup failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            task = nil
        }
    }

    private func observeReferences() {
        let current = withObservationTracking { retainedIDs } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                self.observeReferences()
            }
        }
        if !previousIDs.subtracting(current).isEmpty { request() }
        previousIDs = current
    }
}

import Foundation

/// Coordinates temporary content readers with destructive storage maintenance.
/// Readers may overlap, including while maintenance is queued. Only an active maintenance
/// operation blocks new readers, so nested preview/drag access cannot deadlock behind a writer.
@MainActor public final class ContentAccessGate {
    private var activeReaders = 0
    private var maintenanceActive = false
    private var maintenanceWaiters: [CheckedContinuation<Void, Never>] = []
    private var readerWaiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func withAccess<T>(_ operation: @MainActor () async throws -> T) async rethrows -> T {
        await beginAccess()
        defer { endAccess() }
        return try await operation()
    }

    public func withMaintenance<T>(_ operation: @MainActor () async throws -> T) async rethrows -> T {
        await beginMaintenance()
        defer { endMaintenance() }
        return try await operation()
    }

    /// Synchronous lease acquisition for native drag/preview callbacks.
    /// Returns false only while maintenance is actively running.
    @discardableResult public func tryBeginAccess() -> Bool {
        guard !maintenanceActive else { return false }
        activeReaders += 1
        return true
    }

    /// Releases a lease acquired by `tryBeginAccess`.
    public func endAccess() {
        precondition(activeReaders > 0, "Content access lease released without acquisition")
        activeReaders -= 1
        startWaitingMaintenanceIfPossible()
    }

    private func beginAccess() async {
        guard maintenanceActive else {
            activeReaders += 1
            return
        }
        // Readers are reserved as a batch when maintenance ends; this lets a waiting
        // maintenance request see them and prevents it from cutting in before resumption.
        await withCheckedContinuation { readerWaiters.append($0) }
    }

    private func beginMaintenance() async {
        if !maintenanceActive && activeReaders == 0 {
            maintenanceActive = true
            return
        }
        await withCheckedContinuation { maintenanceWaiters.append($0) }
    }

    private func endMaintenance() {
        precondition(maintenanceActive, "Maintenance lease released without acquisition")
        if !maintenanceWaiters.isEmpty {
            maintenanceWaiters.removeFirst().resume()
            return
        }
        maintenanceActive = false
        activeReaders += readerWaiters.count
        let waitingReaders = readerWaiters
        readerWaiters.removeAll()
        waitingReaders.forEach { $0.resume() }
        startWaitingMaintenanceIfPossible()
    }

    private func startWaitingMaintenanceIfPossible() {
        guard !maintenanceActive, activeReaders == 0, !maintenanceWaiters.isEmpty else { return }
        maintenanceActive = true
        maintenanceWaiters.removeFirst().resume()
    }
}

import Foundation
import Observation
import MurinookDomain

public enum UpdateState: Sendable, Equatable {
    case idle
    case checking
    case upToDate
    case available(AppRelease)
    case failed
}

@MainActor @Observable
public final class UpdateStore {
    public private(set) var state: UpdateState = .idle
    private let source: any ReleaseSource
    private let currentVersion: ReleaseVersion
    @ObservationIgnored private var checkTask: Task<AppRelease?, Error>?
    @ObservationIgnored private var checkID: UUID?

    public init(source: any ReleaseSource, currentVersion: ReleaseVersion) {
        self.source = source
        self.currentVersion = currentVersion
    }

    public func check() async {
        if let checkTask {
            _ = try? await checkTask.value
            return
        }
        let id = UUID()
        checkID = id
        state = .checking
        let source = self.source
        let task = Task { try await source.latestStableRelease() }
        checkTask = task
        do {
            let release = try await task.value
            guard checkID == id else { return }
            state = release.map { $0.version > currentVersion ? .available($0) : .upToDate } ?? .upToDate
        } catch {
            guard checkID == id else { return }
            state = Task.isCancelled ? .idle : .failed
        }
        if checkID == id { checkTask = nil; checkID = nil }
    }

    public func cancel() {
        guard checkTask != nil else { return }
        checkID = nil
        checkTask?.cancel()
        checkTask = nil
        state = .idle
    }
}

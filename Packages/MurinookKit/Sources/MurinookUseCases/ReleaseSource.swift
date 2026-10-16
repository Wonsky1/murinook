import MurinookDomain

public protocol ReleaseSource: Sendable {
    func latestStableRelease() async throws -> AppRelease?
}

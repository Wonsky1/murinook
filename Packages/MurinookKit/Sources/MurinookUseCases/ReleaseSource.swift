import MurinookDomain

public protocol ReleaseSource: Sendable {
    func latestRelease(includingPrereleases: Bool) async throws -> AppRelease?
}

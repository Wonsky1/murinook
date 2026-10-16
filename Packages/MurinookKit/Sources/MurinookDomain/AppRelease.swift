import Foundation

public struct AppRelease: Sendable, Equatable {
    public let version: ReleaseVersion
    public let pageURL: URL
    public let downloadURL: URL?

    public init(version: ReleaseVersion, pageURL: URL, downloadURL: URL? = nil) {
        self.version = version
        self.pageURL = pageURL
        self.downloadURL = downloadURL
    }
}

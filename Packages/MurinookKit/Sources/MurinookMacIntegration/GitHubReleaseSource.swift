import Foundation
import MurinookDomain
import MurinookUseCases

public struct GitHubReleaseSource: ReleaseSource {
    private let owner: String
    private let repository: String
    private let session: URLSession

    public init(owner: String, repository: String, session: URLSession = .shared) {
        self.owner = owner
        self.repository = repository
        self.session = session
    }

    public func latestStableRelease() async throws -> AppRelease? {
        guard Self.validPathPart(owner), Self.validPathPart(repository) else { throw ReleaseSourceError.invalidConfiguration }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/repos/\(owner)/\(repository)/releases/latest"
        guard let url = components.url else { throw ReleaseSourceError.invalidConfiguration }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Murinook", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ReleaseSourceError.invalidResponse }
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else { throw ReleaseSourceError.httpStatus(http.statusCode) }
        guard data.count <= 1_048_576 else { throw ReleaseSourceError.responseTooLarge }
        let payload: Payload
        do { payload = try JSONDecoder().decode(Payload.self, from: data) }
        catch { throw ReleaseSourceError.invalidResponse }
        guard !payload.draft, !payload.prerelease else { return nil }
        guard let version = ReleaseVersion(payload.tagName), !version.isPrerelease else { return nil }
        guard let page = Self.httpsURL(payload.htmlURL), Self.isGitHubPage(page, owner: owner, repository: repository, tag: payload.tagName) else {
            throw ReleaseSourceError.invalidLink
        }
        var download: URL?
        for asset in payload.assets ?? [] where asset.name.lowercased().hasSuffix(".dmg") {
            guard let url = Self.httpsURL(asset.browserDownloadURL),
                  Self.isGitHubDownload(url, owner: owner, repository: repository, tag: payload.tagName, assetName: asset.name) else {
                throw ReleaseSourceError.invalidLink
            }
            download = url
            break
        }
        return AppRelease(version: version, pageURL: page, downloadURL: download)
    }

    private static func validPathPart(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 100 && value.utf8.allSatisfy {
            ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || $0 == 45 || $0 == 95 || $0 == 46
        } && value != "." && value != ".."
    }

    private static func httpsURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return nil }
        return url
    }

    private static func isGitHubPage(_ url: URL, owner: String, repository: String, tag: String) -> Bool {
        url.host?.lowercased() == "github.com" && url.pathComponents == ["/", owner, repository, "releases", "tag", tag]
            && url.query == nil && url.fragment == nil
    }

    private static func isGitHubDownload(_ url: URL, owner: String, repository: String, tag: String, assetName: String) -> Bool {
        let components = url.pathComponents
        return url.host?.lowercased() == "github.com"
            && components.count == 7
            && Array(components.prefix(6)) == ["/", owner, repository, "releases", "download", tag]
            && !components[6].isEmpty && components[6] == assetName
            && url.query == nil && url.fragment == nil
    }

    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: String
            enum CodingKeys: String, CodingKey { case name; case browserDownloadURL = "browser_download_url" }
        }
        let tagName: String
        let draft: Bool
        let prerelease: Bool
        let htmlURL: String
        let assets: [Asset]?
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name", draft, prerelease, htmlURL = "html_url", assets
        }
    }
}

public enum ReleaseSourceError: Error, Equatable {
    case invalidConfiguration
    case invalidResponse
    case invalidLink
    case responseTooLarge
    case httpStatus(Int)
}

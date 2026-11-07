import XCTest
import MurinookMacIntegration

final class GitHubReleaseSourceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.statusCode = 200
        StubURLProtocol.bodiesByPath = [:]
        StubURLProtocol.failure = nil
        StubURLProtocol.body = Data(#"{"tag_name":"v0.1.0","draft":false,"prerelease":false,"html_url":"https://github.com/Wonsky1/murinook/releases/tag/v0.1.0","assets":[{"name":"Murinook.dmg","browser_download_url":"https://github.com/Wonsky1/murinook/releases/download/v0.1.0/Murinook.dmg"}]}"#.utf8)
    }

    func testParsesOnlyStableReleaseAndSelectsDMG() async throws {
        let result = try await source().latestRelease(includingPrereleases: false)
        let release = try XCTUnwrap(result)
        XCTAssertEqual(release.version.description, "0.1.0")
        XCTAssertEqual(release.downloadURL?.lastPathComponent, "Murinook.dmg")
        XCTAssertEqual(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
    }

    func test404MeansNoStableReleaseAndPrereleasesAreIgnored() async throws {
        StubURLProtocol.statusCode = 404
        let missing = try await source().latestRelease(includingPrereleases: false)
        XCTAssertNil(missing)
        StubURLProtocol.statusCode = 200
        StubURLProtocol.body = Data(#"{"tag_name":"0.2.0-beta.1","draft":false,"prerelease":true,"html_url":"https://github.com/Wonsky1/murinook/releases/tag/0.2.0-beta.1"}"#.utf8)
        let prerelease = try await source().latestRelease(includingPrereleases: false)
        XCTAssertNil(prerelease)
        StubURLProtocol.body = Data(#"{"tag_name":"v0.2.0-beta.1","draft":false,"prerelease":false,"html_url":"https://github.com/Wonsky1/murinook/releases/tag/v0.2.0-beta.1"}"#.utf8)
        let betaTag = try await source().latestRelease(includingPrereleases: false)
        XCTAssertNil(betaTag)
        StubURLProtocol.body = Data(#"{"tag_name":"v0.2.0","draft":true,"prerelease":false,"html_url":"https://github.com/Wonsky1/murinook/releases/tag/v0.2.0"}"#.utf8)
        let draft = try await source().latestRelease(includingPrereleases: false)
        XCTAssertNil(draft)
    }

    func testRejectsArbitraryReleaseAndAssetHostsAndSurfacesHTTPFailures() async throws {
        StubURLProtocol.body = Data(#"{"tag_name":"0.1.0","draft":false,"prerelease":false,"html_url":"https://evil.example/releases/tag/v0.1.0"}"#.utf8)
        do { _ = try await source().latestRelease(includingPrereleases: false); XCTFail("expected invalid link") }
        catch { XCTAssertEqual(error as? ReleaseSourceError, .invalidLink) }
        StubURLProtocol.statusCode = 503
        do { _ = try await source().latestRelease(includingPrereleases: false); XCTFail("expected status failure") }
        catch { XCTAssertEqual(error as? ReleaseSourceError, .httpStatus(503)) }
    }

    func testRejectsArbitraryAssetHost() async throws {
        StubURLProtocol.body = Data(#"{"tag_name":"0.1.0","draft":false,"prerelease":false,"html_url":"https://github.com/Wonsky1/murinook/releases/tag/v0.1.0","assets":[{"name":"Murinook.dmg","browser_download_url":"https://evil.example/Murinook.dmg"}]}"#.utf8)
        do { _ = try await source().latestRelease(includingPrereleases: false); XCTFail("expected invalid link") }
        catch { XCTAssertEqual(error as? ReleaseSourceError, .invalidLink) }
    }

    func testRejectsCrossRepositoryAndWrongTagURLs() async throws {
        for page in [
            "https://github.com/other/murinook/releases/tag/v0.1.0",
            "https://github.com/Wonsky1/other/releases/tag/v0.1.0",
            "https://github.com/Wonsky1/murinook/releases/tag/v0.1.1",
            "https://github.com:444/Wonsky1/murinook/releases/tag/v0.1.0"
        ] {
            StubURLProtocol.body = Data(#"{"tag_name":"v0.1.0","draft":false,"prerelease":false,"html_url":"\#(page)"}"#.utf8)
            do { _ = try await source().latestRelease(includingPrereleases: false); XCTFail("expected invalid link: \(page)") }
            catch { XCTAssertEqual(error as? ReleaseSourceError, .invalidLink) }
        }

        StubURLProtocol.body = Data(#"{"tag_name":"v0.1.0","draft":false,"prerelease":false,"html_url":"https://github.com/Wonsky1/murinook/releases/tag/v0.1.0","assets":[{"name":"Murinook.dmg","browser_download_url":"https://github.com/Wonsky1/murinook/releases/download/v0.1.1/Murinook.dmg"}]}"#.utf8)
        do { _ = try await source().latestRelease(includingPrereleases: false); XCTFail("expected wrong asset tag failure") }
        catch { XCTAssertEqual(error as? ReleaseSourceError, .invalidLink) }
    }

    func testSurfacesTransportErrors() async throws {
        StubURLProtocol.failure = URLError(.notConnectedToInternet)
        do { _ = try await source().latestRelease(includingPrereleases: false); XCTFail("expected transport failure") }
        catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
        StubURLProtocol.failure = nil
    }

    func testBetaOptInSelectsNewestSemanticVersionAndKeepsStableEligible() async throws {
        StubURLProtocol.bodiesByPath["/repos/Wonsky1/murinook/releases"] = releaseList([
            ("v0.2.0-beta.2", true, false), ("v0.2.0-beta.10", true, false),
            ("v0.1.0", false, false), ("v0.9.0-beta.1", true, true)
        ])
        let beta = try await source().latestRelease(includingPrereleases: true)
        XCTAssertEqual(beta?.version.description, "0.2.0-beta.10")
        XCTAssertEqual(beta?.downloadURL?.lastPathComponent, "Murinook.dmg")

        StubURLProtocol.bodiesByPath["/repos/Wonsky1/murinook/releases"] = releaseList([
            ("v0.2.0-beta.10", true, false), ("v0.2.0", false, false)
        ])
        let stable = try await source().latestRelease(includingPrereleases: true)
        XCTAssertEqual(stable?.version.description, "0.2.0")
    }

    func testStableChannelStillUsesLatestEndpointAndExcludesBetaTags() async throws {
        StubURLProtocol.bodiesByPath["/repos/Wonsky1/murinook/releases"] = releaseList([("v0.9.0-beta.1", true, false)])
        let stable = try await source().latestRelease(includingPrereleases: false)
        XCTAssertEqual(stable?.version.description, "0.1.0")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/repos/Wonsky1/murinook/releases/latest")
    }

    func testBetaListCannotHideNewerStableOutsideListOrIncludeDrafts() async throws {
        StubURLProtocol.body = releaseList([("v0.3.0", false, false)])
        let array = try XCTUnwrap(JSONSerialization.jsonObject(with: StubURLProtocol.body) as? [[String: Any]])
        StubURLProtocol.body = try JSONSerialization.data(withJSONObject: array[0])
        StubURLProtocol.bodiesByPath["/repos/Wonsky1/murinook/releases"] = releaseList([
            ("v0.2.0-beta.10", true, false), ("v9.0.0", false, true), ("not-a-version", true, false)
        ])
        let result = try await source().latestRelease(includingPrereleases: true)
        XCTAssertEqual(result?.version.description, "0.3.0")
    }

    func testBetaChannelRejectsUntrustedSelectedDownload() async throws {
        var list = try XCTUnwrap(JSONSerialization.jsonObject(with: releaseList([("v0.2.0-beta.1", true, false)])) as? [[String: Any]])
        list[0]["assets"] = [["name": "Murinook.dmg", "browser_download_url": "https://evil.example/Murinook.dmg"]]
        StubURLProtocol.bodiesByPath["/repos/Wonsky1/murinook/releases"] = try JSONSerialization.data(withJSONObject: list)
        do { _ = try await source().latestRelease(includingPrereleases: true); XCTFail("expected invalid link") }
        catch { XCTAssertEqual(error as? ReleaseSourceError, .invalidLink) }
    }

    private func releaseList(_ values: [(String, Bool, Bool)]) -> Data {
        let payloads: [[String: Any]] = values.map { tag, prerelease, draft in
            ["tag_name": tag, "draft": draft, "prerelease": prerelease,
             "html_url": "https://github.com/Wonsky1/murinook/releases/tag/" + tag,
             "assets": [["name": "Murinook.dmg", "browser_download_url": "https://github.com/Wonsky1/murinook/releases/download/" + tag + "/Murinook.dmg"]]]
        }
        return try! JSONSerialization.data(withJSONObject: payloads)
    }

    private func source() -> GitHubReleaseSource {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return GitHubReleaseSource(owner: "Wonsky1", repository: "murinook", session: URLSession(configuration: configuration))
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var bodiesByPath: [String: Data] = [:]
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var failure: Error?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let failure = Self.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        Self.lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"] )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.bodiesByPath[request.url!.path] ?? Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

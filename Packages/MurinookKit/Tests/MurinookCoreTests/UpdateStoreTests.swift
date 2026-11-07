import XCTest
import MurinookDomain
import MurinookUseCases

@MainActor
final class UpdateStoreTests: XCTestCase {
    func testStableVersionIsNewerThanSameBasePrereleaseAndNumericComponentsCompareNumerically() throws {
        let beta = try XCTUnwrap(ReleaseVersion("0.1.0-beta.1"))
        let stable = try XCTUnwrap(ReleaseVersion("v0.1.0"))
        XCTAssertLessThan(beta, stable)
        XCTAssertLessThan(try XCTUnwrap(ReleaseVersion("0.9.0")), try XCTUnwrap(ReleaseVersion("0.10.0")))
    }

    func testMalformedAndOverflowVersionsAreRejected() {
        for invalid in ["", "0.1", "0.1.0-", "0.1.0-../evil", "999999999999999999999.1.0"] {
            XCTAssertNil(ReleaseVersion(invalid), invalid)
        }
    }

    func testCurrentBetaReceivesSameBaseStableRelease() async throws {
        let release = AppRelease(version: try XCTUnwrap(ReleaseVersion("0.1.0")), pageURL: URL(string: "https://github.com/a/b/releases/tag/v0.1.0")!)
        let store = UpdateStore(source: StubSource(result: .success(release)), currentVersion: try XCTUnwrap(ReleaseVersion("0.1.0-beta.1")))
        await store.check()
        XCTAssertEqual(store.state, .available(release))
    }

    func testOlderOrSameReleaseIsUpToDateAndNilIsUpToDate() async throws {
        let older = AppRelease(version: try XCTUnwrap(ReleaseVersion("0.9.0")), pageURL: URL(string: "https://github.com/a/b/releases/tag/v0.9.0")!)
        for result: Result<AppRelease?, Error> in [.success(older), .success(nil)] {
            let store = UpdateStore(source: StubSource(result: result), currentVersion: try XCTUnwrap(ReleaseVersion("1.0.0")))
            await store.check()
            XCTAssertEqual(store.state, .upToDate)
        }
    }

    func testConcurrentChecksShareOneRequest() async throws {
        let release = AppRelease(version: try XCTUnwrap(ReleaseVersion("0.2.0")), pageURL: try XCTUnwrap(URL(string: "https://github.com/a/b/releases/tag/v0.2.0")))
        let source = GatedSource()
        let store = UpdateStore(source: source, currentVersion: try XCTUnwrap(ReleaseVersion("0.1.0")))
        let first = Task { await store.check() }
        await source.waitUntilStarted()
        let secondStarted = AsyncStream<Void>.makeStream()
        let second = Task {
            secondStarted.continuation.yield(())
            await store.check()
        }
        for await _ in secondStarted.stream { break }
        await Task.yield()
        await source.succeed(release)
        await first.value
        await second.value
        let callCount = await source.callCount()
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(store.state, .available(release))
    }

    func testCancellationIgnoresLateAvailableResultAndSourceErrorsFail() async throws {
        let release = AppRelease(version: try XCTUnwrap(ReleaseVersion("0.2.0")), pageURL: try XCTUnwrap(URL(string: "https://github.com/a/b/releases/tag/v0.2.0")))
        let gated = GatedSource()
        let store = UpdateStore(source: gated, currentVersion: try XCTUnwrap(ReleaseVersion("0.1.0")))
        let checking = Task { await store.check() }
        await gated.waitUntilStarted()
        store.cancel()
        await gated.succeed(release)
        await checking.value
        XCTAssertEqual(store.state, .idle)

        let failed = UpdateStore(source: StubSource(result: .failure(StubFailure.expected)), currentVersion: try XCTUnwrap(ReleaseVersion("0.1.0")))
        await failed.check()
        XCTAssertEqual(failed.state, .failed)
    }

    func testBetaChoiceIsForwardedAndTurningItOffClearsBetaOffer() async throws {
        let release = AppRelease(version: try XCTUnwrap(ReleaseVersion("0.1.0-beta.10")), pageURL: URL(string: "https://github.com/a/b/releases/tag/v0.1.0-beta.10")!)
        let source = PreviewSource(release: release)
        let store = UpdateStore(source: source, currentVersion: try XCTUnwrap(ReleaseVersion("0.1.0-beta.9")))
        await store.check()
        XCTAssertEqual(store.state, .upToDate)
        await store.check(includingPrereleases: true)
        XCTAssertEqual(store.state, .available(release))
        await store.check(includingPrereleases: false)
        XCTAssertEqual(store.state, .upToDate)
        let choices = await source.choices
        XCTAssertEqual(choices, [false, true, false])
    }

    func testSwitchingToStableIgnoresLateBetaResponse() async throws {
        let beta = AppRelease(version: try XCTUnwrap(ReleaseVersion("0.2.0-beta.1")), pageURL: URL(string: "https://github.com/a/b/releases/tag/v0.2.0-beta.1")!)
        let source = SwitchingSource()
        let store = UpdateStore(source: source, currentVersion: try XCTUnwrap(ReleaseVersion("0.1.0")))
        let betaCheck = Task { await store.check(includingPrereleases: true) }
        await source.waitUntilBetaStarted()
        let stableCheck = Task { await store.check(includingPrereleases: false) }
        let deadline = ContinuousClock.now + .seconds(1)
        while !(await source.stableStarted), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        let stableStarted = await source.stableStarted
        XCTAssertTrue(stableStarted, "Changing channel must start a new request instead of sharing the old beta request")
        await source.finishBeta(beta)
        await betaCheck.value
        await stableCheck.value
        XCTAssertEqual(store.state, .upToDate, "The late beta result must not reappear after opting out")
    }

    func testBetaOptInDoesNotOfferDowngradeFromStable() async throws {
        let release = AppRelease(version: try XCTUnwrap(ReleaseVersion("0.1.0-beta.10")), pageURL: URL(string: "https://github.com/a/b/releases/tag/v0.1.0-beta.10")!)
        let store = UpdateStore(source: PreviewSource(release: release), currentVersion: try XCTUnwrap(ReleaseVersion("0.1.0")))
        await store.check(includingPrereleases: true)
        XCTAssertEqual(store.state, .upToDate)
    }

    func testBetaUpdateOptInPersistsAndMissingPreferenceDefaultsToOff() throws {
        let optedIn = try JSONDecoder().decode(AppPreferences.self, from: Data(#"{"includeBetaUpdates":true}"#.utf8))
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(optedIn)) as? [String: Any]
        XCTAssertEqual(encoded?["includeBetaUpdates"] as? Bool, true)

        let legacy = try JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))
        let legacyEncoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any]
        XCTAssertEqual(legacyEncoded?["includeBetaUpdates"] as? Bool, false)
    }

    func testLegacyPreferencesDefaultAutomaticChecksToTrue() throws {
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))
        XCTAssertTrue(decoded.automaticallyChecksForUpdates)
        var disabled = AppPreferences()
        disabled.automaticallyChecksForUpdates = false
        let roundTrip = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(disabled))
        XCTAssertFalse(roundTrip.automaticallyChecksForUpdates)
    }
}

private struct StubSource: ReleaseSource {
    let result: Result<AppRelease?, Error>
    func latestRelease(includingPrereleases: Bool) async throws -> AppRelease? { try result.get() }
}

private enum StubFailure: Error { case expected }

private actor GatedSource: ReleaseSource {
    private(set) var calls = 0
    private var resultContinuations: [CheckedContinuation<AppRelease?, Error>] = []
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var hasStarted = false

    func latestRelease(includingPrereleases: Bool) async throws -> AppRelease? {
        calls += 1
        hasStarted = true
        startContinuation?.resume()
        startContinuation = nil
        return try await withCheckedThrowingContinuation { resultContinuations.append($0) }
    }

    func waitUntilStarted() async {
        if hasStarted { return }
        await withCheckedContinuation { startContinuation = $0 }
    }

    func callCount() -> Int { calls }

    func succeed(_ release: AppRelease) {
        let pending = resultContinuations
        resultContinuations.removeAll()
        for continuation in pending { continuation.resume(returning: release) }
    }
}

private actor PreviewSource: ReleaseSource {
    let release: AppRelease
    private(set) var choices: [Bool] = []
    init(release: AppRelease) { self.release = release }
    func latestRelease(includingPrereleases: Bool) async throws -> AppRelease? {
        choices.append(includingPrereleases)
        return includingPrereleases ? release : nil
    }
}

private actor SwitchingSource: ReleaseSource {
    private(set) var stableStarted = false
    private var betaContinuation: CheckedContinuation<AppRelease?, Error>?
    private var startContinuation: CheckedContinuation<Void, Never>?

    func latestRelease(includingPrereleases: Bool) async throws -> AppRelease? {
        guard includingPrereleases else { stableStarted = true; return nil }
        return try await withCheckedThrowingContinuation { continuation in
            betaContinuation = continuation
            startContinuation?.resume()
            startContinuation = nil
        }
    }

    func waitUntilBetaStarted() async {
        if betaContinuation != nil { return }
        await withCheckedContinuation { startContinuation = $0 }
    }

    func finishBeta(_ release: AppRelease) {
        betaContinuation?.resume(returning: release)
        betaContinuation = nil
    }
}

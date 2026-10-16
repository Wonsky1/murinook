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
    func latestStableRelease() async throws -> AppRelease? { try result.get() }
}

private enum StubFailure: Error { case expected }

private actor GatedSource: ReleaseSource {
    private(set) var calls = 0
    private var resultContinuations: [CheckedContinuation<AppRelease?, Error>] = []
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var hasStarted = false

    func latestStableRelease() async throws -> AppRelease? {
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

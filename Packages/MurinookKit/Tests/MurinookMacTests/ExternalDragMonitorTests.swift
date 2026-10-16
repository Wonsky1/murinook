import AppKit
import XCTest
@testable import MurinookMacIntegration

@MainActor
final class ExternalDragMonitorTests: XCTestCase {
    func testFileURLCandidateUsesOnlyChangedPasteboardMetadataBeforeDrop() {
        let source = FakeDragPasteboardSource(types: [.fileURL])
        let monitor = ExternalDragMonitor(source: source, includesText: true)
        var candidates: [ExternalDragCandidate] = []
        monitor.onCandidate = { candidates.append($0) }

        source.changeCount = 1
        monitor.poll(buttonDown: true)

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.typeIdentifiers, [NSPasteboard.PasteboardType.fileURL.rawValue])
        XCTAssertFalse(candidates.first?.containsFilePromise ?? true)
        XCTAssertEqual(source.typeReads, 1)
    }

    func testCandidateRequiresSupportedDeclaredTypeAndMouseButtonDown() {
        let source = FakeDragPasteboardSource(types: [NSPasteboard.PasteboardType("com.example.unknown")])
        let monitor = ExternalDragMonitor(source: source, includesText: true)
        var candidateCount = 0
        monitor.onCandidate = { _ in candidateCount += 1 }

        source.changeCount = 1
        monitor.poll(buttonDown: false)
        XCTAssertEqual(candidateCount, 0)
        source.changeCount = 2
        monitor.poll(buttonDown: true)
        XCTAssertEqual(candidateCount, 0)
    }

    func testPromiseCandidateIsIdentifiedFromDeclaredTypesAlone() {
        let promise = NSPasteboard.PasteboardType(NSFilePromiseReceiver.readableDraggedTypes[0])
        let source = FakeDragPasteboardSource(types: [promise])
        let monitor = ExternalDragMonitor(source: source, includesText: true)
        var candidate: ExternalDragCandidate?
        monitor.onCandidate = { candidate = $0 }

        source.changeCount = 1
        monitor.poll(buttonDown: true)

        XCTAssertTrue(candidate?.containsFilePromise == true)
        XCTAssertEqual(source.typeReads, 1)
    }
}

@MainActor
private final class FakeDragPasteboardSource: ExternalDragPasteboardSource {
    var changeCount = 0
    private let declared: [NSPasteboard.PasteboardType]?
    private(set) var typeReads = 0

    init(types: [NSPasteboard.PasteboardType]?) { declared = types }

    var types: [NSPasteboard.PasteboardType]? {
        typeReads += 1
        return declared
    }
}

import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import MurinookMacIntegration

@MainActor
final class ShelfDropDestinationTests: XCTestCase {
    func testDirectDOCXFileURLIsAcceptedAndDropReceivesActualSenderPasteboard() {
        let pasteboard = makePasteboard(types: [.fileURL], fileURL: URL(fileURLWithPath: "/tmp/report.docx"))
        let destination = makeDestination()
        var receivedPasteboard: NSPasteboard?
        destination.onDrop = { receivedPasteboard = $0; return true }
        let info = FakeDraggingInfo(pasteboard: pasteboard)

        XCTAssertEqual(destination.draggingEntered(info), .copy)
        XCTAssertEqual(destination.draggingUpdated(info), .copy)
        XCTAssertTrue(destination.prepareForDragOperation(info))
        XCTAssertTrue(destination.performDragOperation(info))
        XCTAssertTrue(receivedPasteboard === pasteboard)
    }

    func testDirectUnknownExtensionFileAndFolderAreAcceptedAsFileURLs() {
        for url in [URL(fileURLWithPath: "/tmp/archive.murinook-unknown"), URL(fileURLWithPath: "/tmp/Folder", isDirectory: true)] {
            let pasteboard = makePasteboard(types: [.fileURL], fileURL: url)
            let destination = makeDestination()
            let info = FakeDraggingInfo(pasteboard: pasteboard)
            XCTAssertEqual(destination.draggingEntered(info), .copy, "Should accept file URL \(url)")
        }
    }

    func testDOCXDocumentTypeIsAcceptedWithoutExtensionSpecificFiltering() {
        let docxType = UTType(filenameExtension: "docx")!
        let destination = makeDestination()
        let info = FakeDraggingInfo(pasteboard: makePasteboard(types: [NSPasteboard.PasteboardType(docxType.identifier)]))

        XCTAssertEqual(destination.draggingEntered(info), .copy)
    }

    func testMixedLegacyPromiseTypeFallsBackToDirectFileURLWhenNoReceiverCanBeRead() {
        let promiseType = NSPasteboard.PasteboardType(NSFilePromiseReceiver.readableDraggedTypes[0])
        let pasteboard = makePasteboard(types: [promiseType, .fileURL], fileURL: URL(fileURLWithPath: "/tmp/report.docx"))
        let destination = makeDestination()
        destination.onDrop = { $0 === pasteboard }
        let info = FakeDraggingInfo(pasteboard: pasteboard)

        XCTAssertEqual(destination.draggingEntered(info), .copy)
        XCTAssertTrue(destination.prepareForDragOperation(info))
        XCTAssertTrue(destination.performDragOperation(info))
    }

    func testPromiseMarkerWithoutReadableReceiverAndWithoutFileURLIsRejected() {
        let promiseType = NSPasteboard.PasteboardType(NSFilePromiseReceiver.readableDraggedTypes[0])
        let info = FakeDraggingInfo(pasteboard: makePasteboard(types: [promiseType]))
        let destination = makeDestination()

        XCTAssertEqual(destination.draggingEntered(info), [])
        XCTAssertFalse(destination.prepareForDragOperation(info))
    }

    func testUnsupportedEmptyAndNonCopyDragsAreRejectedByEveryGate() {
        let unknown = NSPasteboard.PasteboardType("com.example.murinook.unknown-\(UUID().uuidString)")
        let unsupportedInfo = FakeDraggingInfo(pasteboard: makePasteboard(types: [unknown]), sourceMask: .copy)
        let emptyInfo = FakeDraggingInfo(pasteboard: makePasteboard(types: []), sourceMask: .copy)
        let moveOnlyInfo = FakeDraggingInfo(pasteboard: makePasteboard(types: [.fileURL], fileURL: URL(fileURLWithPath: "/tmp/x")), sourceMask: .move)
        let destination = makeDestination()

        for info in [unsupportedInfo, emptyInfo, moveOnlyInfo] {
            XCTAssertEqual(destination.draggingEntered(info), [])
            XCTAssertEqual(destination.draggingUpdated(info), [])
            XCTAssertFalse(destination.prepareForDragOperation(info))
            XCTAssertFalse(destination.performDragOperation(info))
        }
    }

    func testDisabledDestinationRejectsOtherwiseSupportedFileURL() {
        let destination = ShelfDropDestinationView(contentView: NSView())
        destination.isDropEnabled = { false }
        let info = FakeDraggingInfo(pasteboard: makePasteboard(types: [.fileURL], fileURL: URL(fileURLWithPath: "/tmp/x")))

        XCTAssertEqual(destination.draggingEntered(info), [])
        XCTAssertEqual(destination.draggingUpdated(info), [])
        XCTAssertFalse(destination.prepareForDragOperation(info))
    }

    func testDropWithoutHandlerReturnsFalseAndEntryCallbackRunsOnce() {
        let destination = makeDestination()
        var entryCount = 0
        destination.onDragEntered = { entryCount += 1 }
        let info = FakeDraggingInfo(pasteboard: makePasteboard(types: [.fileURL], fileURL: URL(fileURLWithPath: "/tmp/x")))

        XCTAssertEqual(destination.draggingEntered(info), .copy)
        XCTAssertEqual(entryCount, 1)
        XCTAssertFalse(destination.performDragOperation(info))
    }

    func testContainerHitTestingContinuesIntoHostedControls() {
        let controls = NSView(frame: NSRect(x: 20, y: 20, width: 30, height: 30))
        let hosted = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        hosted.addSubview(controls)
        let destination = ShelfDropDestinationView(contentView: hosted)
        destination.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        destination.layoutSubtreeIfNeeded()

        let hit = destination.hitTest(NSPoint(x: 25, y: 25))
        XCTAssertTrue(hit === controls || hit?.isDescendant(of: controls) == true)
    }

    private func makeDestination() -> ShelfDropDestinationView {
        ShelfDropDestinationView(contentView: NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100)))
    }

    private func makePasteboard(types: [NSPasteboard.PasteboardType], fileURL: URL? = nil) -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ShelfDropDestinationTests-\(UUID().uuidString)"))
        pasteboard.declareTypes(types, owner: nil)
        if let fileURL { pasteboard.setString(fileURL.absoluteString, forType: .fileURL) }
        return pasteboard
    }
}

@MainActor
private final class FakeDraggingInfo: NSObject, @preconcurrency NSDraggingInfo {
    let draggingPasteboard: NSPasteboard
    let draggingSourceOperationMask: NSDragOperation
    var draggingDestinationWindow: NSWindow? { nil }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    var draggedImage: NSImage? { nil }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 0
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }

    init(pasteboard: NSPasteboard, sourceMask: NSDragOperation = .copy) {
        self.draggingPasteboard = pasteboard
        self.draggingSourceOperationMask = sourceMask
        super.init()
    }

    func slideDraggedImage(to screenPoint: NSPoint) {}
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions, for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any], using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
    func resetSpringLoading() {}
}

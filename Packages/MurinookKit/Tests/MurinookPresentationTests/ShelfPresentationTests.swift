import Testing
@testable import MurinookPresentation

@Test func compactShelfLayoutFitsContentAndCapsLongLists() {
    #expect(ShelfLayout.width == 260)
    #expect(ShelfLayout.height(for: 0) == 112)
    #expect(ShelfLayout.height(for: 1) == 112)
    #expect(ShelfLayout.height(for: 2) == 148)
    #expect(ShelfLayout.height(for: 100) == 320)
}

@Test func cancelledExternalDragRestoresHiddenShelf() {
    var state = ShelfPresentation()
    state.externalDragStarted()
    #expect(state.mode == .expanded)
    state.externalDragEnded()
    #expect(state.mode == .hidden)
}

@Test func successfulDropKeepsShelfExpanded() {
    var state = ShelfPresentation()
    state.externalDragStarted()
    state.dropSucceeded(itemCount: 2)
    state.externalDragEnded()
    #expect(state.mode == .expanded)
    state.hide()
    #expect(state.mode == .collapsed)
    state.restore()
    #expect(state.mode == .expanded)
}

@Test func collapsedShelfReturnsToTabAfterCancelledDrag() {
    var state = ShelfPresentation(itemCount: 2)
    state.restore()
    state.hide()
    state.externalDragStarted()
    state.externalDragEnded()
    #expect(state.mode == .collapsed)
}

@Test func lateDropAfterMouseReleaseRemainsOpen() {
    var state = ShelfPresentation()
    state.externalDragStarted()
    state.externalDragEnded()
    state.dropSucceeded(itemCount: 1)
    #expect(state.mode == .expanded)
}

@Test func emptyShelfHidesInsteadOfLeavingTab() {
    var state = ShelfPresentation(itemCount: 1)
    state.restore()
    state.hide()
    state.itemsChanged(count: 0)
    #expect(state.mode == .hidden)
}

@Test func manualCollapseIsNotUndoneByDragEnd() {
    var state = ShelfPresentation(itemCount: 1)
    state.restore()
    state.externalDragStarted()
    state.hide()
    state.externalDragEnded()
    #expect(state.mode == .collapsed)
}

@Test func lateImportDoesNotUndoManualCollapse() {
    var state = ShelfPresentation(itemCount: 1)
    state.externalDragStarted()
    state.externalDragEnded()
    state.hide()
    state.dropSucceeded(itemCount: 2)
    #expect(state.mode == .collapsed)
}

@Test func emptyShelfClosesAfterLastItemLeaves() {
    var state = ShelfPresentation(itemCount: 1)
    state.restore()
    state.itemsChanged(count: 0)
    #expect(state.mode == .hidden)
}

@Test func manualRestoreDoesNotExposeIdleEmptyShelf() {
    var state = ShelfPresentation()
    state.restore()
    #expect(state.mode == .hidden)
}

@Test func removingLastItemDuringDragDoesNotRestoreEmptyExpandedShelf() {
    var state = ShelfPresentation(itemCount: 1)
    state.restore()
    state.externalDragStarted()
    state.itemsChanged(count: 0)
    state.externalDragEnded()
    #expect(state.mode == .hidden)
}

@Test func emptyImportDoesNotLeaveIdleShelfExpanded() {
    var state = ShelfPresentation()
    state.externalDragStarted()
    state.dropSucceeded(itemCount: 0)
    state.externalDragEnded()
    #expect(state.mode == .hidden)
}

@Test func addingFirstItemAfterRestoreOpensPopulatedShelf() {
    var state = ShelfPresentation()
    state.restore()
    state.itemsChanged(count: 1)
    #expect(state.mode == .expanded)
}

@Test func hidingBeforeFirstItemArrivesKeepsOnlyRestoreTab() {
    var state = ShelfPresentation()
    state.restore()
    state.hide()
    state.itemsChanged(count: 1)
    #expect(state.mode == .collapsed)
}

import Testing
@testable import MurinookPresentation

@Test func dockFollowsOpenWindowsAndWaitsForLastWindowToClose() {
    var state = DockPresenceState()
    #expect(!state.shouldShowIcon)
    state.setOpen(true, for: .library)
    #expect(state.shouldShowIcon)
    state.setOpen(true, for: .settings)
    state.setOpen(false, for: .library)
    #expect(state.shouldShowIcon)
    state.setOpen(false, for: .settings)
    #expect(!state.shouldShowIcon)
}

@Test func dockCanRemainVisibleWhenUserExplicitlyChoosesAlwaysShow() {
    var state = DockPresenceState()
    state.alwaysShowIcon = true
    #expect(state.shouldShowIcon)
    state.setOpen(true, for: .queue)
    state.setOpen(false, for: .queue)
    #expect(state.shouldShowIcon)
    state.alwaysShowIcon = false
    #expect(!state.shouldShowIcon)
}

@Test func duplicateWindowLifecycleEventsAreIdempotent() {
    var state = DockPresenceState()
    state.setOpen(true, for: .quickAccess)
    state.setOpen(true, for: .quickAccess)
    state.setOpen(false, for: .quickAccess)
    #expect(!state.shouldShowIcon)
    state.setOpen(false, for: .quickAccess)
    #expect(!state.shouldShowIcon)
    state.setOpen(true, for: .onboarding)
    #expect(state.shouldShowIcon)
}

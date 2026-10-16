import Testing
@testable import MurinookPresentation

@Test func freshLaunchShowsOnboardingAndReturningLaunchDoesNot() {
    var firstLaunch = ApplicationPresentationState()
    let shouldShowFirstRunOnboarding = firstLaunch.launch()
    #expect(shouldShowFirstRunOnboarding)
    #expect(firstLaunch.onboardingVisible)

    var returningLaunch = ApplicationPresentationState(onboardingCompleted: true)
    let shouldShowReturningOnboarding = returningLaunch.launch()
    #expect(!shouldShowReturningOnboarding)
    #expect(!returningLaunch.onboardingVisible)
}

@Test func completingOnboardingMarksItCompleteAndHidesIt() {
    var state = ApplicationPresentationState()
    let shouldShowOnboarding = state.launch()
    #expect(shouldShowOnboarding)

    state.completeOnboarding()

    #expect(state.onboardingCompleted)
    #expect(!state.onboardingVisible)
}

@Test func firstLibraryCloseShowsExplanationOnlyOnce() {
    var state = ApplicationPresentationState(onboardingCompleted: true)
    let shouldShowOnboarding = state.launch()
    #expect(!shouldShowOnboarding)

    let shouldShowExplanation = state.libraryClosed()
    #expect(shouldShowExplanation)
    #expect(state.backgroundExplanationVisible)
    let shouldRepeatExplanation = state.libraryClosed()
    #expect(!shouldRepeatExplanation)
    #expect(state.backgroundExplanationVisible)

    state.dismissBackgroundExplanation()
    #expect(!state.backgroundExplanationVisible)
    let shouldShowAgain = state.libraryClosed()
    #expect(!shouldShowAgain)
    #expect(state.backgroundExplanationAcknowledged)
}

@Test func libraryCloseDuringOnboardingDoesNotShowExplanation() {
    var state = ApplicationPresentationState()
    let shouldShowOnboarding = state.launch()
    #expect(shouldShowOnboarding)

    let shouldShowExplanation = state.libraryClosed()
    #expect(!shouldShowExplanation)
    #expect(!state.backgroundExplanationVisible)
}

@Test func libraryCloseDuringTerminationDoesNotShowExplanation() {
    var state = ApplicationPresentationState(onboardingCompleted: true)
    let shouldShowOnboarding = state.launch()
    #expect(!shouldShowOnboarding)
    state.terminate()

    let shouldShowExplanation = state.libraryClosed()
    #expect(!shouldShowExplanation)
    #expect(!state.backgroundExplanationVisible)
}

@Test func acknowledgedExplanationStaysDismissedAcrossLaunchStateInstances() {
    var state = ApplicationPresentationState(
        onboardingCompleted: true,
        backgroundExplanationAcknowledged: true
    )
    let shouldShowOnboarding = state.launch()
    #expect(!shouldShowOnboarding)

    let shouldShowExplanation = state.libraryClosed()
    #expect(!shouldShowExplanation)
    #expect(!state.backgroundExplanationVisible)
}

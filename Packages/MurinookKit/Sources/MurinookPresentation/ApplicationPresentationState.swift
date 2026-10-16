/// Launch, onboarding, and first-close education state for the app presentation layer.
/// Persisted acknowledgements are supplied by the app composition root.
public struct ApplicationPresentationState: Sendable {
    public private(set) var onboardingCompleted: Bool
    public private(set) var onboardingVisible = false
    public private(set) var backgroundExplanationAcknowledged: Bool
    public private(set) var backgroundExplanationVisible = false
    public private(set) var terminating = false

    public init(
        onboardingCompleted: Bool = false,
        backgroundExplanationAcknowledged: Bool = false
    ) {
        self.onboardingCompleted = onboardingCompleted
        self.backgroundExplanationAcknowledged = backgroundExplanationAcknowledged
    }

    /// Returns whether this launch should present first-run onboarding.
    public mutating func launch() -> Bool {
        onboardingVisible = !onboardingCompleted
        return onboardingVisible
    }

    public mutating func completeOnboarding() {
        onboardingCompleted = true
        onboardingVisible = false
    }

    /// Returns true when this close should present the first-close explanation.
    public mutating func libraryClosed() -> Bool {
        guard !terminating,
              !onboardingVisible,
              !backgroundExplanationAcknowledged,
              !backgroundExplanationVisible else {
            return false
        }
        backgroundExplanationVisible = true
        return true
    }

    public mutating func dismissBackgroundExplanation() {
        backgroundExplanationAcknowledged = true
        backgroundExplanationVisible = false
    }

    public mutating func terminate() {
        terminating = true
    }
}

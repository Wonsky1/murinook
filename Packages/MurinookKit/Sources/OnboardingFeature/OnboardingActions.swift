public struct OnboardingActions {
    public var requestPostEventAccess: () -> Bool
    public var openAccessibilitySettings: () -> Void
    public var hasPostEventAccess: () -> Bool
    public var permissionGranted: () -> Void
    public var hasWindowAccessibilityAccess: () -> Bool
    public var requestWindowAccessibilityAccess: () -> Bool
    public var finish: () -> Void
    public init(requestPostEventAccess: @escaping () -> Bool = { false }, openAccessibilitySettings: @escaping () -> Void = {},
                hasPostEventAccess: @escaping () -> Bool = { true }, permissionGranted: @escaping () -> Void = {},
                finish: @escaping () -> Void = {},
                hasWindowAccessibilityAccess: @escaping () -> Bool = { false },
                requestWindowAccessibilityAccess: @escaping () -> Bool = { false }) {
        self.requestPostEventAccess = requestPostEventAccess
        self.openAccessibilitySettings = openAccessibilitySettings
        self.hasPostEventAccess = hasPostEventAccess
        self.permissionGranted = permissionGranted
        self.hasWindowAccessibilityAccess = hasWindowAccessibilityAccess
        self.requestWindowAccessibilityAccess = requestWindowAccessibilityAccess
        self.finish = finish
    }
}

public struct OnboardingActions {
    public var requestPostEventAccess: () -> Void
    public var openAccessibilitySettings: () -> Void
    public var hasPostEventAccess: () -> Bool
    public var permissionGranted: () -> Void
    public var finish: () -> Void
    public init(requestPostEventAccess: @escaping () -> Void = {}, openAccessibilitySettings: @escaping () -> Void = {},
                hasPostEventAccess: @escaping () -> Bool = { true }, permissionGranted: @escaping () -> Void = {},
                finish: @escaping () -> Void = {}) {
        self.requestPostEventAccess = requestPostEventAccess
        self.openAccessibilitySettings = openAccessibilitySettings
        self.hasPostEventAccess = hasPostEventAccess
        self.permissionGranted = permissionGranted
        self.finish = finish
    }
}

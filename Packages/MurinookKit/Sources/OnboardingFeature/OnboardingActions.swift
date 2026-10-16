public struct OnboardingActions {
    public var requestPastePermission: () -> Void
    public var openAccessibilitySettings: () -> Void
    public var finish: () -> Void
    public init(requestPastePermission: @escaping () -> Void = {}, openAccessibilitySettings: @escaping () -> Void = {},
                finish: @escaping () -> Void = {}) {
        self.requestPastePermission = requestPastePermission
        self.openAccessibilitySettings = openAccessibilitySettings
        self.finish = finish
    }
}

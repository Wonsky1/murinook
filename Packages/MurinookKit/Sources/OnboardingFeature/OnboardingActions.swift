public struct OnboardingActions {
    public var requestPastePermission: () -> Void
    public var openAccessibilitySettings: () -> Void
    public var hasPastePermission: () -> Bool
    public var permissionGranted: () -> Void
    public var finish: () -> Void
    public init(requestPastePermission: @escaping () -> Void = {}, openAccessibilitySettings: @escaping () -> Void = {},
                hasPastePermission: @escaping () -> Bool = { true }, permissionGranted: @escaping () -> Void = {},
                finish: @escaping () -> Void = {}) {
        self.requestPastePermission = requestPastePermission
        self.openAccessibilitySettings = openAccessibilitySettings
        self.hasPastePermission = hasPastePermission
        self.permissionGranted = permissionGranted
        self.finish = finish
    }
}

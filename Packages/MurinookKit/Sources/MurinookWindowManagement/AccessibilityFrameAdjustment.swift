/// Scopes the app's optional enhanced-UI state to a synchronous native write.
@MainActor
enum AccessibilityFrameAdjustment {
    static func perform(readEnhancedUI: () -> Bool?, writeEnhancedUI: (Bool) -> Bool,
                        adjustment: () throws -> Void) throws {
        // Enhanced UI can animate AX frame writes, leaving immediate readback
        // partway through a resize. Never enable a state we didn't disable.
        let disabled = readEnhancedUI() == true && writeEnhancedUI(false)
        defer { if disabled { _ = writeEnhancedUI(true) } }
        try adjustment()
    }
}

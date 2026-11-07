/// Failures are surfaced by the owning feature's localized UI. A failed operation
/// may have partially changed a window; Restore remains available in that case.
public enum WindowManagementError: Error, Equatable, Sendable {
    case accessibilityRequired
    case noWindow
    case unsupportedWindow
    case noOtherDisplay
    case noRestoreFrame
    case operationFailed
}

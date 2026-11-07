import CoreGraphics
import Foundation

struct WindowApplication: Equatable, Sendable {
    let processIdentifier: Int32
    let launchDate: Date?
}

@MainActor
protocol WindowReference: AnyObject {
    var processIdentifier: Int32 { get }
    func isSameWindow(as other: any WindowReference) -> Bool
}

struct WindowState {
    let frame: CGRect
    let isMinimized: Bool
    let isFullScreen: Bool
    let canMove: Bool
    let canResize: Bool
}

/// The native boundary owns observation and AX timeouts, but never activates apps.
@MainActor
protocol WindowSystem: AnyObject {
    var ownProcessIdentifier: Int32 { get }
    var hasAccessibilityAccess: Bool { get }
    var currentApplication: WindowApplication? { get }
    var displays: [WindowDisplay] { get }
    func requestAccessibilityAccess() -> Bool
    func isAlive(_ application: WindowApplication) -> Bool
    func focusedWindow(in application: WindowApplication) throws -> any WindowReference
    func state(of window: any WindowReference) throws -> WindowState
    func setFrame(_ frame: CGRect, of window: any WindowReference) throws
    func observeApplications(_ callback: @escaping @MainActor (WindowApplication) -> Void)
    func observeFocusedWindow(in application: WindowApplication, callback: @escaping @MainActor () -> Void)
    func stopObserving()
}

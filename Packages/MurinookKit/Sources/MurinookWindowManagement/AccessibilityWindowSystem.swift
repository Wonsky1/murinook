import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
private final class AccessibilityWindowReference: WindowReference {
    let element: AXUIElement
    let processIdentifier: Int32

    init(element: AXUIElement, processIdentifier: Int32) {
        self.element = element
        self.processIdentifier = processIdentifier
        AXUIElementSetMessagingTimeout(element, 0.2)
    }

    func isSameWindow(as other: any WindowReference) -> Bool {
        guard let other = other as? AccessibilityWindowReference else { return false }
        return processIdentifier == other.processIdentifier && CFEqual(element, other.element)
    }
}

@MainActor
final class AccessibilityWindowSystem: WindowSystem {
    let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    private var activationObservation: WorkspaceWindowObservation?
    private var focusObservation: AccessibilityFocusObservation?
    private let diagnostics: @MainActor (WindowManagementDiagnostic) -> Void

    init(diagnostics: @escaping @MainActor (WindowManagementDiagnostic) -> Void = { _ in }) {
        self.diagnostics = diagnostics
    }

    var hasAccessibilityAccess: Bool { AXIsProcessTrusted() }

    var currentApplication: WindowApplication? {
        NSWorkspace.shared.frontmostApplication.map(Self.applicationIdentity)
    }

    var displays: [WindowDisplay] {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return [] }
        return screens.compactMap { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return WindowDisplay(
                id: id.uint32Value,
                frame: WindowGeometry.accessibilityFrame(fromAppKit: screen.frame, primaryScreenTop: primary.frame.maxY),
                visibleFrame: WindowGeometry.accessibilityFrame(fromAppKit: screen.visibleFrame, primaryScreenTop: primary.frame.maxY)
            )
        }
    }

    func requestAccessibilityAccess() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func isAlive(_ application: WindowApplication) -> Bool {
        guard let running = NSRunningApplication(processIdentifier: application.processIdentifier), !running.isTerminated else { return false }
        return running.launchDate == application.launchDate
    }

    func focusedWindow(in application: WindowApplication) throws -> any WindowReference {
        guard application.processIdentifier != ownProcessIdentifier, isAlive(application) else { throw WindowManagementError.noWindow }
        let app = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.2)
        let value = try attribute(kAXFocusedWindowAttribute, of: app)
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { throw WindowManagementError.noWindow }
        let element = unsafeDowncast(value, to: AXUIElement.self)
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid == application.processIdentifier else { throw WindowManagementError.noWindow }
        return AccessibilityWindowReference(element: element, processIdentifier: pid)
    }

    func state(of window: any WindowReference) throws -> WindowState {
        let element = try nativeElement(window)
        guard try attribute(kAXRoleAttribute, of: element) as? String == kAXWindowRole,
              try attribute(kAXSubroleAttribute, of: element) as? String == kAXStandardWindowSubrole else {
            throw WindowManagementError.unsupportedWindow
        }
        let frame = try frame(of: element)
        let minimized = try boolean(kAXMinimizedAttribute, of: element)
        // Not every app implements AXFullScreen. Missing support means there is
        // no declared fullscreen state; other AX failures remain visible.
        let fullScreen: Bool
        do { fullScreen = try boolean("AXFullScreen", of: element) }
        catch WindowManagementError.unsupportedWindow { fullScreen = false }
        return WindowState(frame: frame, isMinimized: minimized, isFullScreen: fullScreen,
                           canMove: try isSettable(kAXPositionAttribute, of: element),
                           canResize: try isSettable(kAXSizeAttribute, of: element))
    }

    func setFrame(_ desired: CGRect, of window: any WindowReference) throws {
        let element = try nativeElement(window)
        let app = AXUIElementCreateApplication(window.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.2)
        try AccessibilityFrameAdjustment.perform(readEnhancedUI: {
            var value: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(app, "AXEnhancedUserInterface" as CFString, &value)
            let enabled = status == .success ? value as? Bool : nil
            self.diagnostics(WindowManagementDiagnostic(stage: "enhancedUIRead", fields:
                ["targetPID": String(window.processIdentifier), "enabled": enabled.map(String.init) ?? "unknown",
                 "status": String(status.rawValue)]))
            return enabled
        }, writeEnhancedUI: { enabled in
            let status = AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString,
                enabled ? kCFBooleanTrue : kCFBooleanFalse)
            self.diagnostics(WindowManagementDiagnostic(stage: "enhancedUIWrite", fields:
                ["targetPID": String(window.processIdentifier), "enabled": String(enabled), "status": String(status.rawValue)]))
            return status == .success
        }) {
            try writeFrame(desired, to: element, processIdentifier: window.processIdentifier)
        }
    }

    private func writeFrame(_ desired: CGRect, to element: AXUIElement, processIdentifier: Int32) throws {
        let initial = try frame(of: element)
        if initial.size != desired.size { try setSize(desired.size, of: element) }
        if initial.origin != desired.origin { try setPosition(desired.origin, of: element) }
        // Some apps clamp size to the old screen before accepting a display
        // transfer. Retry once on the destination, then let the manager verify.
        let actual = try frame(of: element)
        diagnostics(WindowManagementDiagnostic(stage: "frameNativeObserved", fields:
            ["targetPID": String(processIdentifier)]
                .merging(WindowManagementDiagnostic.frameFields(actual, prefix: "actual")) { _, new in new }))
        if abs(actual.width - desired.width) > 2 || abs(actual.height - desired.height) > 2 {
            try setSize(desired.size, of: element)
        }
        if abs(actual.minX - desired.minX) > 2 || abs(actual.minY - desired.minY) > 2 {
            try setPosition(desired.origin, of: element)
        }
    }

    func observeApplications(_ callback: @escaping @MainActor (WindowApplication) -> Void) {
        activationObservation = WorkspaceWindowObservation(callback: callback)
    }

    func observeFocusedWindow(in application: WindowApplication, callback: @escaping @MainActor () -> Void) {
        focusObservation = nil
        guard hasAccessibilityAccess, isAlive(application) else { return }
        focusObservation = AccessibilityFocusObservation(processIdentifier: application.processIdentifier, callback: callback)
    }

    func stopObserving() {
        activationObservation = nil
        focusObservation = nil
    }

    private static func applicationIdentity(_ app: NSRunningApplication) -> WindowApplication {
        WindowApplication(processIdentifier: app.processIdentifier, launchDate: app.launchDate)
    }

    private func nativeElement(_ window: any WindowReference) throws -> AXUIElement {
        guard let reference = window as? AccessibilityWindowReference,
              reference.processIdentifier != ownProcessIdentifier else { throw WindowManagementError.noWindow }
        var pid: pid_t = 0
        guard AXUIElementGetPid(reference.element, &pid) == .success, pid == reference.processIdentifier else {
            throw WindowManagementError.noWindow
        }
        return reference.element
    }

    private func attribute(_ name: String, of element: AXUIElement) throws -> CFTypeRef {
        var value: CFTypeRef?
        try check(AXUIElementCopyAttributeValue(element, name as CFString, &value), operation: "read", attribute: name)
        guard let value else { throw WindowManagementError.noWindow }
        return value
    }

    private func boolean(_ name: String, of element: AXUIElement) throws -> Bool {
        guard let result = try attribute(name, of: element) as? Bool else { throw WindowManagementError.unsupportedWindow }
        return result
    }

    private func frame(of element: AXUIElement) throws -> CGRect {
        let position = try attribute(kAXPositionAttribute, of: element)
        let size = try attribute(kAXSizeAttribute, of: element)
        guard CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else {
            throw WindowManagementError.unsupportedWindow
        }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &dimensions) else { throw WindowManagementError.unsupportedWindow }
        return CGRect(origin: point, size: dimensions)
    }

    private func isSettable(_ name: String, of element: AXUIElement) throws -> Bool {
        var result = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, name as CFString, &result)
        if error == .attributeUnsupported || error == .notImplemented { return false }
        try check(error, operation: "capability", attribute: name)
        return result.boolValue
    }

    private func setPosition(_ position: CGPoint, of element: AXUIElement) throws {
        var position = position
        guard let value = AXValueCreate(.cgPoint, &position) else { throw WindowManagementError.operationFailed }
        try check(AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value), operation: "write", attribute: kAXPositionAttribute)
    }

    private func setSize(_ size: CGSize, of element: AXUIElement) throws {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { throw WindowManagementError.operationFailed }
        try check(AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value), operation: "write", attribute: kAXSizeAttribute)
    }

    private func check(_ error: AXError, operation: String, attribute: String) throws {
        if error != .success {
            diagnostics(WindowManagementDiagnostic(stage: "axFailure", fields:
                ["operation": operation, "attribute": attribute, "status": String(error.rawValue)]))
        }
        switch error {
        case .success: return
        case .apiDisabled: throw WindowManagementError.accessibilityRequired
        case .invalidUIElement, .noValue: throw WindowManagementError.noWindow
        case .attributeUnsupported, .notImplemented: throw WindowManagementError.unsupportedWindow
        default: throw WindowManagementError.operationFailed
        }
    }
}

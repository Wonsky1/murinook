import AppKit
import ApplicationServices
import Foundation

/// Notification/CFRunLoop registrations remove themselves even if the owner is
/// released without an explicit stop. Callbacks run synchronously on main; there
/// are no queued Tasks that can resurrect a stopped manager.
final class WorkspaceWindowObservation: @unchecked Sendable {
    private let center: NotificationCenter
    private var tokens: [NSObjectProtocol] = []

    @MainActor
    init(callback: @escaping @MainActor (WindowApplication) -> Void) {
        center = NSWorkspace.shared.notificationCenter
        tokens.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let application = WindowApplication(processIdentifier: app.processIdentifier, launchDate: app.launchDate)
            MainActor.assumeIsolated {
                callback(application)
            }
        })
    }

    deinit { for token in tokens { center.removeObserver(token) } }
}

private final class AccessibilityFocusCallback: @unchecked Sendable {
    let action: @MainActor () -> Void
    init(action: @escaping @MainActor () -> Void) { self.action = action }
}

final class AccessibilityFocusObservation: @unchecked Sendable {
    private let observer: AXObserver
    private let application: AXUIElement
    private let callback: AccessibilityFocusCallback
    private let source: CFRunLoopSource

    @MainActor
    init?(processIdentifier: Int32, callback: @escaping @MainActor () -> Void) {
        var observer: AXObserver?
        let error = AXObserverCreate(processIdentifier, { _, _, _, context in
            guard let context else { return }
            let callback = Unmanaged<AccessibilityFocusCallback>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { callback.action() }
        }, &observer)
        guard error == .success, let observer else { return nil }
        self.observer = observer
        application = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.2)
        self.callback = AccessibilityFocusCallback(action: callback)
        source = AXObserverGetRunLoopSource(observer)
        let context = Unmanaged.passUnretained(self.callback).toOpaque()
        guard AXObserverAddNotification(observer, application, kAXFocusedWindowChangedNotification as CFString, context) == .success else { return nil }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    deinit {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        AXObserverRemoveNotification(observer, application, kAXFocusedWindowChangedNotification as CFString)
    }
}

import AppKit
import CoreGraphics
import Foundation
import MurinookDomain

public struct PasteDispatchResult: Sendable, Equatable {
    public enum Status: Sendable { case dispatched, accessibilityPermissionRequired, destinationUnavailable, clipboardWriteFailed, commandDispatchFailed }
    public let status: Status
    public let clipboardChangeCount: Int?
    public let detail: String?
}

@MainActor
public final class PastePermission {
    private let postEventAccessCheck: () -> Bool
    private let postEventAccessRequest: () -> Void

    public init(
        postEventAccessCheck: @escaping () -> Bool = { CGPreflightPostEventAccess() },
        postEventAccessRequest: @escaping () -> Void = { _ = CGRequestPostEventAccess() }
    ) {
        self.postEventAccessCheck = postEventAccessCheck
        self.postEventAccessRequest = postEventAccessRequest
    }

    public var hasPostEventAccess: Bool { postEventAccessCheck() }
    public func requestPostEventAccess() { postEventAccessRequest() }
}

private final class WorkspaceActivationObserver: @unchecked Sendable {
    private let center: NotificationCenter
    private let token: NSObjectProtocol
    init(center: NotificationCenter, token: NSObjectProtocol) { self.center = center; self.token = token }
    deinit { center.removeObserver(token) }
}

/// Copies the selected payload, returns focus to the prior external app, and sends Cmd+V.
/// Successful event posting does not confirm that the destination inserted the content.
@MainActor
public final class PasteDispatcher {
    private let writer: ClipboardContentWriter
    private let permission: PastePermission
    private let applicationBundleIdentifier: String
    private var lastExternalApplication: NSRunningApplication?
    private var activationObserver: WorkspaceActivationObserver?

    public init(writer: ClipboardContentWriter, permission: PastePermission? = nil, applicationBundleIdentifier: String) {
        self.writer = writer
        self.permission = permission ?? PastePermission()
        self.applicationBundleIdentifier = applicationBundleIdentifier
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier != applicationBundleIdentifier {
            lastExternalApplication = frontmost
        }
        let center = NSWorkspace.shared.notificationCenter
        let token = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in self?.rememberIfExternal(application) }
        }
        activationObserver = WorkspaceActivationObserver(center: center, token: token)
    }

    /// Lets the app explicitly pin a destination when a workflow already knows the intended app.
    public func setExternalDestination(_ application: NSRunningApplication?) {
        guard let application else { lastExternalApplication = nil; return }
        guard application.bundleIdentifier != applicationBundleIdentifier else { return }
        lastExternalApplication = application
    }

    public func paste(_ content: [ClipboardItemSnapshot], plainTextOnly: Bool = false) async -> PasteDispatchResult {
        guard permission.hasPostEventAccess else {
            permission.requestPostEventAccess()
            return PasteDispatchResult(status: .accessibilityPermissionRequired, clipboardChangeCount: nil, detail: nil)
        }
        if let frontmost = NSWorkspace.shared.frontmostApplication { rememberIfExternal(frontmost) }
        guard let destination = lastExternalApplication, !destination.isTerminated else {
            return PasteDispatchResult(status: .destinationUnavailable, clipboardChangeCount: nil, detail: "No previous external app is available.")
        }
        let payload = plainTextOnly ? Self.plainTextProjection(content) : content
        guard !payload.isEmpty else {
            return PasteDispatchResult(status: .clipboardWriteFailed, clipboardChangeCount: nil, detail: "There is no matching content to paste.")
        }
        let token: ClipboardWriteToken
        do { token = try writer.write(payload) }
        catch {
            return PasteDispatchResult(status: .clipboardWriteFailed, clipboardChangeCount: nil, detail: error.localizedDescription)
        }
        guard destination.activate(options: [.activateAllWindows]), await waitForActivation(of: destination) else {
            return PasteDispatchResult(status: .commandDispatchFailed, clipboardChangeCount: token.changeCount, detail: "The destination app did not become active.")
        }
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else {
            return PasteDispatchResult(status: .commandDispatchFailed, clipboardChangeCount: token.changeCount, detail: "Could not create keyboard events.")
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        return PasteDispatchResult(status: .dispatched, clipboardChangeCount: token.changeCount, detail: nil)
    }

    public func paste(_ content: ClipContent, plainTextOnly: Bool = false) async -> PasteDispatchResult {
        await paste(content.clipboardItems, plainTextOnly: plainTextOnly)
    }

    private func rememberIfExternal(_ application: NSRunningApplication) {
        guard application.bundleIdentifier != applicationBundleIdentifier, !application.isTerminated else { return }
        lastExternalApplication = application
    }

    private func waitForActivation(of application: NSRunningApplication) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(1)
        while ContinuousClock.now < deadline {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier
    }

    private static func plainTextProjection(_ items: [ClipboardItemSnapshot]) -> [ClipboardItemSnapshot] {
        let textType = NSPasteboard.PasteboardType.string.rawValue
        return items.compactMap { item in
            guard let text = item.representations.first(where: { $0.typeIdentifier == textType }) else { return nil }
            return ClipboardItemSnapshot(representations: [text])
        }
    }
}

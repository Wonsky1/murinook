import ApplicationServices
import CoreGraphics
import Foundation

/// Same-process capability results only; no app identities or user content.
public struct PastePermissionDiagnostic: Sendable {
    public enum Trigger: String, Sendable {
        case statusChanged
        case explicitCheck
        case request
    }

    public let trigger: Trigger
    public let postEventAccess: Bool
    public let accessibilityTrusted: Bool
    public let requestResult: Bool?
    public let processIdentifier: Int32
}

@MainActor
public final class PastePermission {
    private struct Capabilities: Equatable {
        let postEvent: Bool
        let accessibility: Bool
    }

    private let postEventAccessCheck: () -> Bool
    private let postEventAccessRequest: () -> Bool
    private let accessibilityTrustCheck: () -> Bool
    private let diagnostics: @MainActor (PastePermissionDiagnostic) -> Void
    private var lastReportedCapabilities: Capabilities?

    public init(
        postEventAccessCheck: @escaping () -> Bool = { CGPreflightPostEventAccess() },
        postEventAccessRequest: @escaping () -> Bool = { CGRequestPostEventAccess() },
        accessibilityTrustCheck: @escaping () -> Bool = { AXIsProcessTrusted() },
        diagnostics: @escaping @MainActor (PastePermissionDiagnostic) -> Void = { _ in }
    ) {
        self.postEventAccessCheck = postEventAccessCheck
        self.postEventAccessRequest = postEventAccessRequest
        self.accessibilityTrustCheck = accessibilityTrustCheck
        self.diagnostics = diagnostics
    }

    public var hasPostEventAccess: Bool {
        let capabilities = currentCapabilities()
        if capabilities != lastReportedCapabilities {
            report(capabilities, trigger: .statusChanged)
        }
        return capabilities.postEvent
    }

    /// A fresh, nonprompting read for an explicit Check Access action. This does
    /// not claim to invalidate any permission state cached inside macOS.
    @discardableResult
    public func checkPostEventAccess() -> Bool {
        let capabilities = currentCapabilities()
        report(capabilities, trigger: .explicitCheck)
        return capabilities.postEvent
    }

    public func requestPostEventAccess() -> Bool {
        let result = postEventAccessRequest()
        report(currentCapabilities(), trigger: .request, requestResult: result)
        return result
    }

    private func currentCapabilities() -> Capabilities {
        Capabilities(postEvent: postEventAccessCheck(), accessibility: accessibilityTrustCheck())
    }

    private func report(_ capabilities: Capabilities, trigger: PastePermissionDiagnostic.Trigger, requestResult: Bool? = nil) {
        lastReportedCapabilities = capabilities
        diagnostics(PastePermissionDiagnostic(trigger: trigger, postEventAccess: capabilities.postEvent,
                                             accessibilityTrusted: capabilities.accessibility, requestResult: requestResult,
                                             processIdentifier: ProcessInfo.processInfo.processIdentifier))
    }
}

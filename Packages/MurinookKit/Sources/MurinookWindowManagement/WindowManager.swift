import CoreGraphics
import MurinookDomain

/// Session-only external-window commands. The owner must call stop() at shutdown.
/// No command activates an app, changes Spaces, or chooses a replacement window.
@MainActor
public final class WindowManager {
    private struct OriginalFrame {
        let application: WindowApplication
        let window: any WindowReference
        let frame: CGRect
        let displays: [WindowDisplay]
        var constrainedPlacement: CGRect?
    }

    private let system: any WindowSystem
    private let diagnostics: @MainActor (WindowManagementDiagnostic) -> Void
    private var lastApplication: WindowApplication?
    private var lastWindow: (any WindowReference)?
    private var observedApplication: WindowApplication?
    private var originalFrames: [OriginalFrame] = []
    private var isStopped = false
    private let restoreLimit = 100

    public convenience init(diagnostics: @escaping @MainActor (WindowManagementDiagnostic) -> Void = { _ in }) {
        self.init(system: AccessibilityWindowSystem(diagnostics: diagnostics), diagnostics: diagnostics)
    }

    init(system: any WindowSystem, diagnostics: @escaping @MainActor (WindowManagementDiagnostic) -> Void = { _ in }) {
        self.system = system
        self.diagnostics = diagnostics
        if let application = system.currentApplication { applicationActivated(application) }
        system.observeApplications { [weak self] application in self?.applicationActivated(application) }
    }

    public var hasAccessibilityAccess: Bool { system.hasAccessibilityAccess }

    @discardableResult
    public func requestAccessibilityAccess() -> Bool { system.requestAccessibilityAccess() }

    @discardableResult
    public func execute(_ action: WindowAction) throws -> WindowPlacementResult {
        var context = ["command": action.rawValue,
                       "frontmostPID": system.currentApplication.map { String($0.processIdentifier) } ?? "none",
                       "targetPID": lastApplication.map { String($0.processIdentifier) } ?? "none"]
        func record(_ stage: String, _ fields: [String: String] = [:]) {
            diagnostics(WindowManagementDiagnostic(stage: stage, fields: context.merging(fields) { _, new in new }))
        }
        record("begin")
        do {
            guard !isStopped else { throw WindowManagementError.noWindow }
            guard hasAccessibilityAccess else { throw WindowManagementError.accessibilityRequired }
            guard let active = system.currentApplication else { throw WindowManagementError.noWindow }
            if active.processIdentifier != system.ownProcessIdentifier { applicationActivated(active) }
            guard let application = lastApplication, application.processIdentifier != system.ownProcessIdentifier,
                  system.isAlive(application), let window = lastWindow,
                  window.processIdentifier == application.processIdentifier else { throw WindowManagementError.noWindow }
            context["targetPID"] = String(application.processIdentifier)
            record("target")

            let state = try system.state(of: window)
            record("frameInitial", WindowManagementDiagnostic.frameFields(state.frame, prefix: "initial"))
            guard !state.isMinimized, !state.isFullScreen, WindowGeometry.isUsable(state.frame) else {
                throw WindowManagementError.unsupportedWindow
            }
            let displays = system.displays.filter { WindowGeometry.isUsable($0.frame) && WindowGeometry.isUsable($0.visibleFrame) }
            let currentDisplay = try WindowGeometry.display(for: state.frame, among: displays)
            let original = originalFrames.first { $0.application == application && $0.window.isSameWindow(as: window) }
            let destination: CGRect
            switch action {
            case .restore:
                guard let original else { throw WindowManagementError.noRestoreFrame }
                destination = try WindowGeometry.restored(original.frame, previousDisplays: original.displays,
                                                          currentDisplays: displays, canResize: state.canResize)
            case .nextDisplay, .previousDisplay:
                let display = try WindowGeometry.adjacentDisplay(to: currentDisplay, among: displays, forward: action == .nextDisplay)
                destination = WindowGeometry.transferred(state.frame, from: currentDisplay.visibleFrame, to: display.visibleFrame)
            default:
                destination = try WindowGeometry.frame(for: action, current: state.frame, visible: currentDisplay.visibleFrame)
            }
            let moves = abs(destination.minX - state.frame.minX) > 0.5 || abs(destination.minY - state.frame.minY) > 0.5
            let resizes = abs(destination.width - state.frame.width) > 0.5 || abs(destination.height - state.frame.height) > 0.5
            guard (!moves || state.canMove), (!resizes || state.canResize) else { throw WindowManagementError.unsupportedWindow }
            guard WindowGeometry.isUsable(destination) else { throw WindowManagementError.operationFailed }
            record("frameRequested", WindowManagementDiagnostic.frameFields(destination, prefix: "requested"))
            do {
                try system.setFrame(destination, of: window)
                var actual = try system.state(of: window).frame
                record("frameObserved", WindowManagementDiagnostic.frameFields(actual, prefix: "actual"))
                var result = WindowPlacementResult.exact
                if !WindowGeometry.approximatelyEqual(actual, destination),
                   // An unchanged larger frame alone cannot distinguish a size
                   // limit from an ignored write. A previous verified placement
                   // permits repeating that layout without treating it as an error.
                   (!WindowGeometry.approximatelyEqual(actual, state.frame, tolerance: 0.5)
                    || original?.constrainedPlacement.map { WindowGeometry.approximatelyEqual($0, actual) } == true),
                   let constrained = WindowGeometry.constrainedFrame(for: action, requested: destination,
                       accepted: actual, visible: currentDisplay.visibleFrame) {
                    record("frameConstrained", WindowManagementDiagnostic.frameFields(constrained, prefix: "adjusted"))
                    try system.setFrame(constrained, of: window)
                    actual = try system.state(of: window).frame
                    record("frameObserved", WindowManagementDiagnostic.frameFields(actual, prefix: "actual"))
                    guard WindowGeometry.approximatelyEqual(actual, constrained) else {
                        record("mismatch", WindowManagementDiagnostic.frameFields(constrained, prefix: "requested")
                            .merging(WindowManagementDiagnostic.frameFields(actual, prefix: "actual")) { _, new in new })
                        throw WindowManagementError.operationFailed
                    }
                    result = .sizeConstrained(frame: actual)
                }
                guard result != .exact || WindowGeometry.approximatelyEqual(actual, destination) else {
                    record("mismatch", WindowManagementDiagnostic.frameFields(destination, prefix: "requested")
                        .merging(WindowManagementDiagnostic.frameFields(actual, prefix: "actual")) { _, new in new })
                    throw WindowManagementError.operationFailed
                }
                let constrainedPlacement: CGRect? = if case .sizeConstrained = result { actual } else { nil }
                rememberOriginal(state.frame, window: window, application: application, displays: displays,
                    constrainedPlacement: constrainedPlacement)
                record("success")
                return result
            } catch {
                // A rejected position/size write can follow a successful write. Preserve
                // recovery when changed, or when the result cannot safely be read back.
                if original == nil {
                    let actual = try? system.state(of: window).frame
                    if let actual { record("frameAfterFailure", WindowManagementDiagnostic.frameFields(actual, prefix: "actual")) }
                    let changedOrUnknown = actual.map { !WindowGeometry.approximatelyEqual($0, state.frame, tolerance: 0.5) } ?? true
                    if changedOrUnknown {
                        rememberOriginal(state.frame, window: window, application: application, displays: displays)
                    }
                }
                throw error
            }
        } catch {
            // Error descriptions can contain external data; emit only our closed
            // error vocabulary and never localizedDescription or arbitrary text.
            let failure = (error as? WindowManagementError).map { String(describing: $0) } ?? "unknown"
            record("failure", ["error": failure])
            throw error
        }
    }

    public func stop() {
        guard !isStopped else { return }
        isStopped = true
        system.stopObserving()
        lastWindow = nil
        lastApplication = nil
        observedApplication = nil
        originalFrames.removeAll()
    }

    private func applicationActivated(_ application: WindowApplication) {
        guard !isStopped else { return }
        if application.processIdentifier == system.ownProcessIdentifier {
            // Read once at the transition; commands invoked from our UI retain
            // this exact element, even if it closes while a menu is open.
            captureFocusedWindow()
            return
        }
        if lastApplication != application { lastWindow = nil }
        lastApplication = application
        captureFocusedWindow(clearOnFailure: true)
        if observedApplication != application {
            observedApplication = application
            system.observeFocusedWindow(in: application) { [weak self] in
                guard let self, self.system.currentApplication == application else { return }
                self.captureFocusedWindow(clearOnFailure: true)
            }
        }
    }

    private func captureFocusedWindow(clearOnFailure: Bool = false) {
        if clearOnFailure { lastWindow = nil }
        guard hasAccessibilityAccess, let application = lastApplication, system.isAlive(application),
              let window = try? system.focusedWindow(in: application),
              window.processIdentifier == application.processIdentifier else { return }
        lastWindow = window
    }

    private func rememberOriginal(_ frame: CGRect, window: any WindowReference, application: WindowApplication,
                                 displays: [WindowDisplay], constrainedPlacement: CGRect? = nil) {
        if let index = originalFrames.firstIndex(where: { $0.application == application && $0.window.isSameWindow(as: window) }) {
            if let constrainedPlacement { originalFrames[index].constrainedPlacement = constrainedPlacement }
            return
        }
        originalFrames.removeAll { !system.isAlive($0.application) }
        if originalFrames.count >= restoreLimit { originalFrames.removeFirst() }
        originalFrames.append(OriginalFrame(application: application, window: window, frame: frame,
            displays: displays, constrainedPlacement: constrainedPlacement))
    }
}

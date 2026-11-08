/// Counts user-facing app windows independently of transient background panels.
public struct DockPresenceState: Sendable {
    public enum Window: Hashable, Sendable { case library, settings, queue, onboarding, quickAccess }
    private var openWindows: Set<Window> = []
    public var alwaysShowIcon = false
    public var shouldShowIcon: Bool { alwaysShowIcon || !openWindows.isEmpty }
    public init() {}
    public mutating func setOpen(_ isOpen: Bool, for window: Window) {
        if isOpen { openWindows.insert(window) } else { openWindows.remove(window) }
    }
}

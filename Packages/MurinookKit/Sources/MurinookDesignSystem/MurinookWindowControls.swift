import SwiftUI

/// Native window actions supplied by the window's composition layer.
public struct MurinookWindowActions: Sendable {
    public let close: @MainActor @Sendable () -> Void
    public let minimize: @MainActor @Sendable () -> Void
    public let zoom: @MainActor @Sendable () -> Void
    public let canMinimize: Bool
    public let canZoom: Bool

    public init(
        close: @escaping @MainActor @Sendable () -> Void,
        minimize: @escaping @MainActor @Sendable () -> Void,
        zoom: @escaping @MainActor @Sendable () -> Void,
        canMinimize: Bool = true,
        canZoom: Bool = true
    ) {
        self.close = close
        self.minimize = minimize
        self.zoom = zoom
        self.canMinimize = canMinimize
        self.canZoom = canZoom
    }
}

private struct MurinookWindowActionsKey: EnvironmentKey {
    static let defaultValue: MurinookWindowActions? = nil
}

public extension EnvironmentValues {
    var murinookWindowActions: MurinookWindowActions? {
        get { self[MurinookWindowActionsKey.self] }
        set { self[MurinookWindowActionsKey.self] = newValue }
    }
}

/// Compact window controls for headers hosted in a custom full-size titlebar.
public struct MurinookWindowControls: View {
    @Environment(\.murinookWindowActions) private var actions

    public init() {}

    public var body: some View {
        if let actions {
            HStack(spacing: 5) {
                WindowControlButton(symbol: "xmark", label: "windowControls.close", isClose: true, action: actions.close)
                if actions.canMinimize {
                    WindowControlButton(symbol: "minus", label: "windowControls.minimize", action: actions.minimize)
                }
                if actions.canZoom {
                    WindowControlButton(
                        symbol: "arrow.up.left.and.arrow.down.right",
                        label: "windowControls.zoom",
                        action: actions.zoom
                    )
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

private struct WindowControlButton: View {
    let symbol: String
    let label: LocalizedStringKey
    var isClose = false
    let action: @MainActor @Sendable () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 22, height: 24)
                .background(background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(Text(label, bundle: .module))
        .accessibilityLabel(Text(label, bundle: .module))
        .onHover { isHovered = $0 }
        .animation(MurinookMotion.feedback(reduceMotion: reduceMotion), value: isHovered)
    }

    private var foreground: Color {
        isHovered && isClose ? MurinookPalette.danger : MurinookPalette.muted
    }

    private var background: Color {
        guard isHovered else { return .clear }
        return isClose ? MurinookPalette.danger.opacity(0.12) : MurinookPalette.text.opacity(0.08)
    }
}

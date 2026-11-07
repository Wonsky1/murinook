import MurinookDesignSystem
import MurinookDomain
import SwiftUI

public struct WindowActionsMenu: View {
    @Environment(\.locale) private var locale
    private let enabled: Bool
    private let shortcut: (WindowAction) -> String?
    private let perform: (WindowAction) -> Void
    private let settings: () -> Void
    private let back: () -> Void

    public init(enabled: Bool, shortcut: @escaping (WindowAction) -> String?,
                perform: @escaping (WindowAction) -> Void,
                settings: @escaping () -> Void, back: @escaping () -> Void) {
        self.enabled = enabled
        self.shortcut = shortcut
        self.perform = perform
        self.settings = settings
        self.back = back
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: back) { Image(systemName: "chevron.left").frame(width: 26, height: 28) }
                    .buttonStyle(.plain).accessibilityLabel(text("window.back"))
                Text(text("window.title")).font(.system(size: 13, weight: .semibold))
                Spacer()
            }.padding(12)
            Divider()
            if enabled {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(WindowAction.allCases, id: \.self) { action in
                            Button { perform(action) } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: WindowActionLabels.symbol(action)).frame(width: 19).accessibilityHidden(true)
                                    Text(WindowActionLabels.title(action, locale: locale))
                                    Spacer(minLength: 8)
                                    if let key = shortcut(action) {
                                        Text(key).font(.system(size: 10)).foregroundStyle(MurinookPalette.muted)
                                    }
                                }
                                .font(.system(size: 12)).padding(.horizontal, 10)
                                .frame(minHeight: 31).frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }.buttonStyle(WindowCommandStyle())
                        }
                    }.padding(6)
                }.frame(height: 390)
            } else {
                Text(text("window.disabledMessage"))
                    .font(.system(size: 12)).foregroundStyle(MurinookPalette.muted)
                    .fixedSize(horizontal: false, vertical: true).padding(18)
            }
            Divider()
            Button(action: settings) {
                Label(text("window.settings"), systemImage: "gearshape")
                    .font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading).padding(13)
            }.buttonStyle(WindowCommandStyle())
        }
        .frame(width: 282).foregroundStyle(MurinookPalette.text).background(MurinookPalette.surface)
    }

    private func text(_ key: String) -> String { WindowActionLabels.text(key, locale: locale) }
}

private struct WindowCommandStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CommandLabel(configuration: configuration)
    }

    private struct CommandLabel: View {
        let configuration: Configuration
        @State private var hovered = false
        var body: some View {
            configuration.label.background(hovered || configuration.isPressed ? MurinookPalette.accentSoft : .clear,
                in: RoundedRectangle(cornerRadius: 5)).onHover { hovered = $0 }
        }
    }
}

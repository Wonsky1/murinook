import AppKit
import SwiftUI

public struct MurinookSearchField: View {
    @Binding private var text: String
    private let prompt: Text
    private let shortcut: Text?
    private let focusOnAppear: Bool
    private let focusShortcut: KeyEquivalent?
    private let moveSelection: ((MoveCommandDirection) -> Void)?
    private let submit: ((Bool) -> Void)?
    private let cancel: (() -> Void)?
    @FocusState private var isFocused: Bool

    public init(text: Binding<String>, prompt: Text, shortcut: Text? = nil, focusOnAppear: Bool = false, focusShortcut: KeyEquivalent? = nil,
                moveSelection: ((MoveCommandDirection) -> Void)? = nil,
                submit: ((Bool) -> Void)? = nil, cancel: (() -> Void)? = nil) {
        self._text = text; self.prompt = prompt; self.shortcut = shortcut; self.focusOnAppear = focusOnAppear
        self.focusShortcut = focusShortcut; self.moveSelection = moveSelection; self.submit = submit; self.cancel = cancel
    }

    public var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(MurinookPalette.muted)
            TextField(text: $text, prompt: prompt) { EmptyView() }
                .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(MurinookPalette.text)
                .focused($isFocused).accessibilityLabel(prompt)
                .onKeyPress(.downArrow) { guard let moveSelection else { return .ignored }; moveSelection(.down); return .handled }
                .onKeyPress(.upArrow) { guard let moveSelection else { return .ignored }; moveSelection(.up); return .handled }
                .onKeyPress(.return, phases: .down) { press in guard let submit else { return .ignored }; submit(press.modifiers.contains(.shift)); return .handled }
                .onKeyPress(.escape) { guard let cancel else { return .ignored }; cancel(); return .handled }
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(MurinookPalette.soft) }
                    .buttonStyle(.plain).accessibilityLabel(Text("search.clear", bundle: .module))
            } else if let shortcut {
                shortcut.font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(MurinookPalette.muted)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(MurinookPalette.surface2, in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .padding(.horizontal, 9).frame(height: 40)
        .background(MurinookPalette.surface, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(MurinookPalette.border, lineWidth: 1))
        .onAppear { if focusOnAppear { isFocused = true } }
        .background {
            if let focusShortcut {
                Button("") { isFocused = true }.keyboardShortcut(focusShortcut).hidden().accessibilityHidden(true)
            }
        }
    }
}

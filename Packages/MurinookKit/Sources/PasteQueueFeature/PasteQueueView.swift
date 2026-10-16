import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

public struct PasteQueueView: View {
    private let store: QueueStore
    private let actions: PasteQueueActions
    private let pasteNextShortcut: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plainTextOnly = false

    public init(store: QueueStore, actions: PasteQueueActions, pasteNextShortcut: String = "⌃⌥V") {
        self.store = store; self.actions = actions; self.pasteNextShortcut = pasteNextShortcut
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(MurinookPalette.border).frame(height: 1)
            if store.entries.isEmpty {
                MurinookEmptyState(symbol: "text.line.first.and.arrowtriangle.forward", title: Text("queue.emptyTitle", bundle: .module), message: Text("queue.emptyMessage", bundle: .module))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                queueList
                    .transition(.opacity)
            }
            footer
        }
        .frame(minWidth: 590, maxWidth: .infinity, minHeight: 470, idealHeight: 530)
        .background(MurinookPalette.window)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(MurinookMotion.settle(reduceMotion: reduceMotion), value: store.entries.map(\.id))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            MurinookWindowControls()
            VStack(alignment: .leading, spacing: 5) {
                Text("queue.eyebrow", bundle: .module).font(.system(size: 11, weight: .bold)).tracking(1.1).foregroundStyle(MurinookPalette.accent)
                Text("queue.title", bundle: .module).font(.system(size: 21, weight: .semibold)).tracking(-0.6).foregroundStyle(MurinookPalette.text)
                HStack(spacing: 4) {
                    Text("queue.itemCount \(store.entries.count)", bundle: .module)
                    Text("·")
                    Text(store.entries.isEmpty ? "queue.noNext" : "queue.nextReady", bundle: .module)
                }.font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
            }
            Spacer()
            Text(pasteNextShortcut).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(MurinookPalette.muted)
                .padding(.horizontal, 8).padding(.vertical, 5).background(MurinookPalette.surface2, in: RoundedRectangle(cornerRadius: 7))
                .accessibilityLabel(Text("queue.pasteNext", bundle: .module))
            Menu {
                Button(role: .destructive) { store.clear() } label: { Label { Text("queue.clear", bundle: .module) } icon: { Image(systemName: "trash") } }.disabled(store.entries.isEmpty)
            } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 22).accessibilityLabel(Text("queue.more", bundle: .module))
        }
        .padding(.horizontal, 23).padding(.top, 20).padding(.bottom, 15).background(MurinookPalette.surface)
    }

    private var queueList: some View {
        List {
            ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                QueueRow(entry: entry, index: index, count: store.entries.count,
                         move: { to in store.move(from: index, to: to) }, skip: { store.remove(entry.id) }, copy: { actions.copy(entry) })
                    .listRowInsets(EdgeInsets(top: 1, leading: 7, bottom: 5, trailing: 7))
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
            }
            .onMove { from, to in guard let index = from.first else { return }; store.move(from: index, to: to > index ? to - 1 : to) }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 8)
        .frame(maxHeight: .infinity)
        .accessibilityLabel(Text("queue.title", bundle: .module))
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Toggle(isOn: $plainTextOnly) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("queue.plainText", bundle: .module).font(.system(size: 11, weight: .medium))
                    Text("queue.plainTextDetail", bundle: .module).font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
                }
            }.toggleStyle(.checkbox).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                Text("queue.dispatchCaveat", bundle: .module).font(.system(size: 11)).foregroundStyle(MurinookPalette.soft).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                if let next = store.next {
                    Button { store.skip() } label: { Text("queue.skip", bundle: .module) }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundStyle(MurinookPalette.accent)
                    Button { plainTextOnly ? actions.pasteNextPlainText(next) : actions.pasteNext(next) } label: {
                        Label { Text("queue.pasteNext", bundle: .module) } icon: { Image(systemName: "arrow.right") }.font(.system(size: 11, weight: .semibold))
                    }.buttonStyle(MurinookButtonStyle(variant: .primary)).keyboardShortcut(.return, modifiers: [])
                }
            }
        }
        .padding(.horizontal, 21).padding(.vertical, 12).background(MurinookPalette.surface)
        .overlay(alignment: .top) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
    }
}

private struct QueueRow: View {
    let entry: QueueEntry; let index: Int; let count: Int
    let move: (Int) -> Void; let skip: () -> Void; let copy: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(index == 0 ? MurinookPalette.onAccent : MurinookPalette.accent)
                .frame(width: 26, height: 26).background(index == 0 ? MurinookPalette.accent : MurinookPalette.surface2, in: Circle())
                .accessibilityLabel(Text("queue.position \(index + 1)", bundle: .module))
            MurinookKindBadge(kindIdentifier: entry.kind.rawValue, symbol: entry.kind.symbolName, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                MurinookContentTitle(entry.title, kindIdentifier: entry.kind.rawValue).font(.system(size: 12, weight: index == 0 ? .semibold : .medium)).foregroundStyle(MurinookPalette.text).lineLimit(1)
                Text(LocalizedStringKey(index == 0 ? "queue.nextItem" : "kind." + entry.kind.rawValue), bundle: .module).font(.system(size: 11)).foregroundStyle(MurinookPalette.muted).lineLimit(1)
            }
            Spacer(minLength: 5)
            rowButton("chevron.up", label: "queue.moveEarlier") { move(max(index - 1, 0)) }.disabled(index == 0)
            rowButton("chevron.down", label: "queue.moveLater") { move(min(index + 1, count - 1)) }.disabled(index == count - 1)
            rowButton("doc.on.doc", label: "quick.copy", action: copy)
            rowButton("xmark", label: "queue.remove", action: skip)
        }
        .frame(maxWidth: .infinity, minHeight: 63).padding(.horizontal, 10)
        .background(index == 0 ? MurinookPalette.accentSoft : MurinookPalette.surface, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(index == 0 ? MurinookPalette.accent.opacity(0.35) : MurinookPalette.border, lineWidth: 1))
        .contextMenu {
            Button { copy() } label: { Text("quick.copy", bundle: .module) }; Button { skip() } label: { Text("queue.skip", bundle: .module) }
            Button { move(max(index - 1, 0)) } label: { Text("queue.moveEarlier", bundle: .module) }.disabled(index == 0)
            Button { move(min(index + 1, count - 1)) } label: { Text("queue.moveLater", bundle: .module) }.disabled(index == count - 1)
        }
    }
    private func rowButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).frame(width: 25, height: 25).contentShape(Rectangle()) }
            .buttonStyle(.plain).foregroundStyle(MurinookPalette.muted).help(Text(LocalizedStringKey(label), bundle: .module)).accessibilityLabel(Text(LocalizedStringKey(label), bundle: .module))
    }
}

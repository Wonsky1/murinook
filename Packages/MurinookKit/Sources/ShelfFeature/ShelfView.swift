import AppKit
import MurinookDesignSystem
import MurinookDomain
import MurinookPresentation
import MurinookUseCases
import SwiftUI
import UniformTypeIdentifiers

public struct ShelfView: View {
    private let store: ShelfStore
    private let actions: ShelfActions
    private let onPlacementChange: (ShelfPlacement) -> Void
    private let placement: ShelfPlacement
    private let headerDragArea: AnyView?
    private let isDragging: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var currentPlacement: ShelfPlacement
    @State private var selectedIDs = Set<UUID>()

    public init(store: ShelfStore, actions: ShelfActions, placement: ShelfPlacement,
                onPlacementChange: @escaping (ShelfPlacement) -> Void = { _ in },
                headerDragArea: AnyView? = nil, isDragging: Bool = false) {
        self.store = store; self.actions = actions
        self.placement = placement
        self.headerDragArea = headerDragArea
        self.isDragging = isDragging
        self._currentPlacement = State(initialValue: placement)
        self.onPlacementChange = onPlacementChange
    }

    public var body: some View {
        ZStack {
          VStack(spacing: 0) {
            header
            if let error = store.error {
                MurinookErrorBanner(localizationKey: error.localizationKey)
                    .padding(.horizontal, 11).padding(.bottom, 7)
            }

            if !store.items.isEmpty {
            List(selection: $selectedIDs) {
                ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                    ShelfRow(item: item,
                             draggedItems: transferItems(for: item),
                             remove: { Task { await store.remove(selectedIDs.isEmpty ? [item.id] : selectedIDs) } },
                             makeDraggingItems: actions.draggingItems, dragStarted: actions.dragStarted, dragCompleted: actions.dragCompleted,
                             preview: { actions.preview(item) },
                             select: { event in
                                 if event.modifierFlags.contains(.command) {
                                     if !selectedIDs.insert(item.id).inserted { selectedIDs.remove(item.id) }
                                 } else if event.modifierFlags.contains(.shift) { selectedIDs.insert(item.id) }
                                 else { selectedIDs = [item.id] }
                             })
                        .tag(item.id)
                        .listRowInsets(EdgeInsets(top: 0, leading: 7, bottom: 0, trailing: 7))
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(MurinookPalette.border)
                        .listRowBackground(selectedIDs.contains(item.id) ? MurinookPalette.accentSoft : MurinookPalette.surface)
                        .contextMenu {
                            Button { actions.preview(item) } label: { Text("shelf.preview", bundle: .module) }
                            Button { Task { await store.group(selectedIDs.union([item.id])) } } label: { Text("shelf.groupSelected", bundle: .module) }
                            Button { Task { await store.ungroup(Set(transferItems(for: item).map(\.id))) } } label: { Text("shelf.ungroup", bundle: .module) }
                            Divider()
                            Button { move(item, by: -1) } label: { Text("shelf.moveUp", bundle: .module) }.disabled(index == 0)
                            Button { move(item, by: 1) } label: { Text("shelf.moveDown", bundle: .module) }.disabled(index == store.items.count - 1)
                            Button(role: .destructive) { Task { await store.remove(selectedIDs.isEmpty ? [item.id] : selectedIDs) } } label: { Text("shelf.remove", bundle: .module) }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: min(CGFloat(store.items.count) * ShelfLayout.rowHeight, ShelfLayout.maximumHeight - 58))
            }
          }
          .frame(width: ShelfLayout.width, height: ShelfLayout.height(for: store.items.count), alignment: .top)

          if isDragging {
              dropTarget
                  .frame(width: ShelfLayout.width, height: ShelfLayout.height(for: store.items.count))
                  .transition(.opacity)
                  .allowsHitTesting(false)
          }
        }
        .frame(width: ShelfLayout.width, height: ShelfLayout.height(for: store.items.count))
        .background(MurinookPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .animation(MurinookMotion.feedback(reduceMotion: reduceMotion), value: isDragging)
        .onChange(of: store.items.map(\.id)) { _, ids in selectedIDs.formIntersection(ids) }
        .onChange(of: placement) { _, value in currentPlacement = value }
        .onChange(of: currentPlacement) { _, value in onPlacementChange(value) }
        .accessibilityAction(named: Text("shelf.hide", bundle: .module), actions.hide)
    }

    private var header: some View {
        HStack(spacing: 7) {
            ZStack(alignment: .leading) {
                if let headerDragArea {
                    headerDragArea.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityHidden(true)
                }
                HStack(spacing: 9) {
                    Image(systemName: "tray.full")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(MurinookPalette.accent)
                        .frame(width: 24, height: 24)
                        .background(MurinookPalette.accentSoft, in: RoundedRectangle(cornerRadius: 8))
                    Text("shelf.title", bundle: .module)
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(MurinookPalette.text)
                    Text("shelf.itemCount \(store.items.count)", bundle: .module)
                        .font(.system(size: 11)).foregroundStyle(MurinookPalette.soft).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(false)
            }
            .frame(height: 29)
            .contentShape(Rectangle())

            .contextMenu {
                Button {
                    currentPlacement.side = currentPlacement.side == .left ? .right : .left
                } label: {
                    Text(currentPlacement.side == .left ? "shelf.rightEdge" : "shelf.leftEdge", bundle: .module)
                }
                Divider()
                Button(role: .destructive) { Task { await store.clear() } } label: { Text("shelf.clear", bundle: .module) }
                    .disabled(store.items.isEmpty)
            }

            ShelfHeaderButton(symbol: "arrow.uturn.backward", localizationKey: "shelf.undo") {
                Task { await store.undoRemoval() }
            }
            .frame(width: 24, height: 27)
            .help(Text("shelf.undo", bundle: .module))
            .accessibilityLabel(Text("shelf.undo", bundle: .module))

            ShelfHeaderButton(symbol: "minus", localizationKey: "shelf.hide", action: actions.hide)
                .frame(width: 24, height: 27)
            .help(Text("shelf.hide", bundle: .module))
            .accessibilityLabel(Text("shelf.hide", bundle: .module))
        }
        .padding(.horizontal, 11).padding(.top, 10).padding(.bottom, 7)
    }

    private var dropTarget: some View {
        VStack(spacing: 5) {
            Image(systemName: "plus").font(.system(size: 16, weight: .medium))
            Text("shelf.dropItems", bundle: .module)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(MurinookPalette.accent)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(reduceTransparency ? AnyShapeStyle(MurinookPalette.surface) : AnyShapeStyle(.ultraThinMaterial),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            .foregroundStyle(MurinookPalette.accent))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("shelf.dropItems", bundle: .module))
    }

    private func transferItems(for item: ShelfItem) -> [ShelfItem] {
        let selected = selectedIDs.contains(item.id) ? store.items.filter { selectedIDs.contains($0.id) } : [item]
        let groups = Set(selected.compactMap(\.groupID))
        let ids = Set(selected.map(\.id))
        return store.items.filter { ids.contains($0.id) || $0.groupID.map(groups.contains) == true }
    }

    private func move(_ item: ShelfItem, by offset: Int) {
        guard let index = store.items.firstIndex(where: { $0.id == item.id }) else { return }
        let destination = index + offset
        guard store.items.indices.contains(destination) else { return }
        Task { await store.move(from: index, to: destination) }
    }
}

private struct ShelfRow: View {
    let item: ShelfItem
    let draggedItems: [ShelfItem]
    let remove: () -> Void
    let makeDraggingItems: @MainActor ([ShelfItem]) async -> [NSDraggingItem]
    let dragStarted: @MainActor ([ShelfItem]) -> Bool
    let dragCompleted: (ShelfItem, Bool) -> Void
    let preview: () -> Void
    let select: (NSEvent) -> Void

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                ShelfDragHandle(items: draggedItems, makeDraggingItems: makeDraggingItems,
                    dragStarted: dragStarted, dragCompleted: dragCompleted, clicked: { event in
                        select(event)
                        if event.clickCount == 2 { preview() }
                    })
                    .accessibilityLabel(Text("shelf.dragItem", bundle: .module))
                HStack(spacing: 9) {
                    Image(systemName: "line.3.horizontal").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary).frame(width: 12)
                    MurinookContentIcon(data: item.iconData, kindIdentifier: item.kind.rawValue,
                        symbol: item.kind.symbolName, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if item.groupID != nil {
                                Image(systemName: "rectangle.stack").font(.system(size: 11)).foregroundStyle(MurinookPalette.accent)
                            }
                            MurinookContentTitle(item.title, kindIdentifier: item.kind.rawValue)
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(MurinookPalette.text).lineLimit(1)
                        }
                        shelfText("shelf.kind.\(item.kind.rawValue)")
                            .font(.system(size: 11)).foregroundStyle(MurinookPalette.soft).lineLimit(1)
                    }
                    Spacer(minLength: 2)
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button(action: remove) { Image(systemName: "xmark") }.accessibilityLabel(Text("shelf.remove", bundle: .module))
                .font(.system(size: 11, weight: .medium)).foregroundStyle(MurinookPalette.soft)
        }
        .buttonStyle(.plain).padding(.horizontal, 1).frame(height: ShelfLayout.rowHeight)
        .accessibilityElement(children: .contain)
    }
}

private func shelfText(_ key: String) -> Text { Text(LocalizedStringKey(key), bundle: .module) }

private struct ShelfHeaderButton: NSViewRepresentable {
    @Environment(\.locale) private var locale
    let symbol: String
    let localizationKey: String
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeNSView(context: Context) -> FirstClickButton {
        let button = FirstClickButton()
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.contentTintColor = .secondaryLabelColor
        button.target = context.coordinator
        button.action = #selector(Coordinator.collapse)
        button.toolTip = String(localized: String.LocalizationValue(localizationKey), bundle: .module, locale: locale)
        button.setAccessibilityLabel(String(localized: String.LocalizationValue(localizationKey), bundle: .module, locale: locale))
        return button
    }

    func updateNSView(_ button: FirstClickButton, context: Context) {
        context.coordinator.action = action
        let label = String(localized: String.LocalizationValue(localizationKey), bundle: .module, locale: locale)
        button.toolTip = label
        button.setAccessibilityLabel(label)
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func collapse() { action() }
    }
}

private final class FirstClickButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

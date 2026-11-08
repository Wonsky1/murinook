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
    private let positionLocked: Bool
    private let onPositionLockChange: (Bool) -> Void
    private let headerDragArea: AnyView?
    private let isDragging: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var selectedIDs = Set<UUID>()

    public init(store: ShelfStore, actions: ShelfActions, positionLocked: Bool = false,
                onPositionLockChange: @escaping (Bool) -> Void = { _ in },
                headerDragArea: AnyView? = nil, isDragging: Bool = false) {
        self.store = store; self.actions = actions
        self.positionLocked = positionLocked
        self.headerDragArea = headerDragArea
        self.isDragging = isDragging
        self.onPositionLockChange = onPositionLockChange
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
                             toggleLock: { Task { await store.setLocked(!item.isLocked, for: item.id) } },
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
                            Button { Task { await store.setLocked(!item.isLocked, for: item.id) } } label: {
                                Text(item.isLocked ? "shelf.item.unlock" : "shelf.item.lock", bundle: .module)
                            }
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
                Button { onPositionLockChange(!positionLocked) } label: {
                    Text(positionLocked ? "shelf.position.unlock" : "shelf.position.lock", bundle: .module)
                }
                Divider()
                Button(role: .destructive) { Task { await store.clear() } } label: { Text("shelf.clear", bundle: .module) }
                    .disabled(store.items.isEmpty)
            }

            ShelfIconButton(symbol: positionLocked ? "lock.fill" : "lock.open",
                localizationKey: positionLocked ? "shelf.position.unlock" : "shelf.position.lock",
                isActive: positionLocked) { onPositionLockChange(!positionLocked) }
                .frame(width: 24, height: 27)

            ShelfIconButton(symbol: "arrow.uturn.backward", localizationKey: "shelf.undo") {
                Task { await store.undoRemoval() }
            }
            .frame(width: 24, height: 27)
            .help(Text("shelf.undo", bundle: .module))
            .accessibilityLabel(Text("shelf.undo", bundle: .module))

            ShelfIconButton(symbol: "minus", localizationKey: "shelf.hide", action: actions.hide)
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

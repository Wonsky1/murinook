import AppKit
import MurinookDesignSystem
import MurinookDomain
import MurinookPresentation
import SwiftUI

struct ShelfRow: View {
    let item: ShelfItem
    let draggedItems: [ShelfItem]
    let remove: () -> Void
    let toggleLock: () -> Void
    let makeDraggingItems: @MainActor ([ShelfItem]) async -> [NSDraggingItem]
    let dragStarted: @MainActor ([ShelfItem]) -> Bool
    let dragCompleted: ([ShelfItem], Bool) -> Void
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
                        Text(LocalizedStringKey("shelf.kind." + item.kind.rawValue), bundle: .module)
                            .font(.system(size: 11)).foregroundStyle(MurinookPalette.soft).lineLimit(1)
                    }
                    Spacer(minLength: 2)
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            ShelfIconButton(symbol: item.isLocked ? "lock.fill" : "lock.open",
                localizationKey: item.isLocked ? "shelf.item.unlock" : "shelf.item.lock",
                isActive: item.isLocked, action: toggleLock)
                .frame(width: 24, height: 27)
            Button(action: remove) { Image(systemName: "xmark") }.accessibilityLabel(Text("shelf.remove", bundle: .module))
                .font(.system(size: 11, weight: .medium)).foregroundStyle(MurinookPalette.soft)
        }
        .buttonStyle(.plain).padding(.horizontal, 1).frame(height: ShelfLayout.rowHeight)
        .accessibilityElement(children: .contain)
    }
}

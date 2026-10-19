import MurinookDesignSystem
import MurinookDomain
import SwiftUI

struct HistoryPresentation: View {
    let groups: [LibraryDayGroup]
    let layout: HistoryLayout
    let query: String
    let selectedIDs: Set<UUID>
    let focusedID: UUID?
    var ordinal: ((Clip) -> Int?)? = nil
    let select: (Clip) -> Void
    let focus: (Clip) -> Void
    let contextMenu: (Clip) -> AnyView
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(Array(groups.enumerated()), id: \.element.id) { groupIndex, group in
                    let startingRank = groups.prefix(groupIndex).reduce(0) { $0 + $1.clips.count }
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text(LocalizedStringKey(group.key), bundle: .module)
                            Rectangle().fill(MurinookPalette.border).frame(height: 1)
                            Text("library.itemCount \(group.clips.count)", bundle: .module).monospacedDigit()
                        }
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(MurinookPalette.soft)
                        groupContents(group.clips, groupID: group.id, startingRank: startingRank)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .scrollIndicators(.automatic)
        .focusable()
        .focusEffectDisabled()
        .animation(MurinookMotion.settle(reduceMotion: reduceMotion), value: layout)
        .onChange(of: focusedID) { _, id in
            guard let id else { return }
            withAnimation(MurinookMotion.settle(reduceMotion: reduceMotion)) { proxy.scrollTo(id, anchor: .center) }
        }
        }
    }

    @ViewBuilder private func groupContents(_ clips: [Clip], groupID: String, startingRank: Int) -> some View {
        switch layout {
        case .grid:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 9)], spacing: 9) {
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in card(clip, rank: startingRank + index + 1, strip: false).id(clip.id) }
            }
        case .list:
            VStack(spacing: 0) {
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in row(clip, rank: startingRank + index + 1).id(clip.id) }
            }.overlay(alignment: .top) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
        case .strip:
            ScrollViewReader { proxy in
                HStack(spacing: 6) {
                    stripButton("history.previous", symbol: "chevron.left") {
                        guard let clip = adjacentClip(in: clips, offset: -1) else { return }
                        focus(clip); withAnimation(MurinookMotion.settle(reduceMotion: reduceMotion)) { proxy.scrollTo(clip.id, anchor: .leading) }
                    }
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 10) {
                            ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in card(clip, rank: startingRank + index + 1, strip: true).id(clip.id) }
                        }.padding(.vertical, 3)
                    }.scrollIndicators(.visible)
                    stripButton("history.next", symbol: "chevron.right") {
                        guard let clip = adjacentClip(in: clips, offset: 1) else { return }
                        focus(clip); withAnimation(MurinookMotion.settle(reduceMotion: reduceMotion)) { proxy.scrollTo(clip.id, anchor: .trailing) }
                    }
                }
                .onChange(of: focusedID) { _, id in
                    guard let id, clips.contains(where: { $0.id == id }) else { return }
                    withAnimation(MurinookMotion.settle(reduceMotion: reduceMotion)) { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
    }

    private func adjacentClip(in clips: [Clip], offset: Int) -> Clip? {
        guard !clips.isEmpty else { return nil }
        let currentIndex = focusedID.flatMap { id in clips.firstIndex { $0.id == id } } ?? (offset < 0 ? clips.count : -1)
        let next = min(max(currentIndex + offset, 0), clips.count - 1)
        return clips[next]
    }

    private func stripButton(_ key: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).frame(width: 23, height: 32) }
            .buttonStyle(.plain).foregroundStyle(MurinookPalette.muted).background(MurinookPalette.surface2, in: RoundedRectangle(cornerRadius: 7))
            .accessibilityLabel(Text(LocalizedStringKey(key), bundle: .module))
    }

    private func row(_ clip: Clip, rank: Int) -> some View {
        Button { select(clip) } label: {
            HStack(spacing: 12) {
                MurinookContentIcon(data: clip.iconData, kindIdentifier: clip.kind.rawValue, symbol: clip.kind.symbolName, size: 30).frame(width: 34, height: 36)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) { title(clip); if clip.isPinned { Image(systemName: "pin.fill").foregroundStyle(MurinookPalette.accent) } }
                    preview(clip).font(.system(size: 11)).foregroundStyle(MurinookPalette.muted).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text(clip.source.name).lineLimit(1).frame(maxWidth: 120, alignment: .trailing)
                Text(clip.lastCopiedAt.formatted(.dateTime.hour().minute().locale(locale))).monospacedDigit()
                Text("\(ordinal?(clip) ?? rank)").monospacedDigit().frame(width: 22)
            }
            .font(.system(size: 11)).foregroundStyle(MurinookPalette.soft).padding(.horizontal, 9).frame(minHeight: 62)
            .modifier(HistoryHoverBackground(isSelected: selectedIDs.contains(clip.id), shape: RoundedRectangle(cornerRadius: 9), selectedColor: MurinookPalette.accentSoft, hoverColor: MurinookPalette.surface2))
            .overlay(alignment: .bottom) { Rectangle().fill(MurinookPalette.border.opacity(0.75)).frame(height: 1) }.contentShape(Rectangle())
        }
        .buttonStyle(.plain).animation(MurinookMotion.feedback(reduceMotion: reduceMotion), value: selectedIDs).modifier(HistorySelectionAccessibility(selected: selectedIDs.contains(clip.id)))
        .contextMenu { contextMenu(clip) }
    }

    private func card(_ clip: Clip, rank: Int, strip: Bool) -> some View {
        Button { select(clip) } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    MurinookContentIcon(data: clip.iconData, kindIdentifier: clip.kind.rawValue, symbol: clip.kind.symbolName, size: strip ? 48 : 31).frame(maxWidth: .infinity, minHeight: strip ? 58 : 34, alignment: .leading)
                    if clip.isPinned { Image(systemName: "pin.fill").font(.system(size: 11)).foregroundStyle(MurinookPalette.accent) }
                }
                title(clip)
                preview(clip).font(.system(size: 11)).foregroundStyle(MurinookPalette.muted).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 1)
                HStack(spacing: 4) {
                    Text(clip.source.name).lineLimit(1); Spacer(minLength: 1)
                    Text(clip.lastCopiedAt.formatted(.dateTime.hour().minute().locale(locale))).monospacedDigit()
                    Text("· \(ordinal?(clip) ?? rank)").monospacedDigit()
                }.font(.system(size: 11)).foregroundStyle(MurinookPalette.soft)
            }
            .padding(11).frame(width: strip ? 205 : nil).frame(maxWidth: strip ? nil : .infinity, minHeight: strip ? 150 : 126, alignment: .topLeading)
            .modifier(HistoryHoverBackground(isSelected: selectedIDs.contains(clip.id), shape: RoundedRectangle(cornerRadius: 12), selectedColor: MurinookPalette.accentSoft, hoverColor: MurinookPalette.surface2, normalColor: MurinookPalette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedIDs.contains(clip.id) ? MurinookPalette.accent.opacity(0.55) : MurinookPalette.border, lineWidth: 1)).contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).animation(MurinookMotion.feedback(reduceMotion: reduceMotion), value: selectedIDs).modifier(HistorySelectionAccessibility(selected: selectedIDs.contains(clip.id)))
        .contextMenu { contextMenu(clip) }
    }

    private func preview(_ clip: Clip) -> some View {
        Group { if clip.preview.isEmpty { libraryText("kind." + clip.kind.rawValue) } else { Text(clip.preview) }
        }
    }
    private func title(_ clip: Clip) -> some View {
        Group {
            if (clip.title == "Image" && clip.kind == .image) || (clip.title == "Content" && clip.preview.isEmpty) { localizedClipTitle(clip) }
            else { MurinookHighlightedText(clip.title, query: query) }
        }
        .font(.system(size: 12, weight: .semibold)).foregroundStyle(MurinookPalette.text).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HistorySelectionAccessibility: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View { content.accessibilityAddTraits(selected ? .isSelected : []) }
}

private struct HistoryHoverBackground<Shape: InsettableShape>: ViewModifier {
    let isSelected: Bool
    let shape: Shape
    let selectedColor: Color
    let hoverColor: Color
    var normalColor: Color = .clear
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(isSelected ? selectedColor : (isHovered ? hoverColor : normalColor), in: shape)
            .onHover { isHovered = $0 }
    }
}

import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

public struct QuickAccessView: View {
    private let store: HistoryStore
    private let actions: QuickAccessActions
    private let preferences: PreferencesStore?
    @Environment(\.locale) private var locale
    @State private var search = ""
    @State private var selectedID: UUID?
    @State private var kindFilter: ClipKind?
    @State private var sourceFilter: String?
    @State private var dateFilter = "anytime"
    @State private var collectionFilter: UUID?
    @State private var pinnedOnly = false
    @State private var isBrandHovered = false
    @State private var isSettingsHovered = false

    public init(store: HistoryStore, actions: QuickAccessActions, preferences: PreferencesStore? = nil) { self.store = store; self.actions = actions; self.preferences = preferences }
    private var layout: HistoryLayout { preferences?.value.historyLayout ?? .list }
    private var sorted: [Clip] { store.clips.sorted { $0.lastCopiedAt > $1.lastCopiedAt } }
    private var results: [Clip] {
        sorted.filter { clip in
            let matchesQuery = search.isEmpty || [clip.title, clip.searchText ?? clip.preview, clip.preview, clip.note, clip.source.name].contains { $0.localizedCaseInsensitiveContains(search) } || clip.tags.contains { $0.localizedCaseInsensitiveContains(search) }
            let matchesDate: Bool = switch dateFilter {
            case "today": Calendar.current.isDateInToday(clip.lastCopiedAt)
            case "week": clip.lastCopiedAt >= (Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast)
            case "month": clip.lastCopiedAt >= (Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .distantPast)
            default: true
            }
            return matchesQuery && (kindFilter.map { clip.kind == $0 } ?? true) && (sourceFilter.map { clip.source.name == $0 } ?? true) && (collectionFilter.map { clip.collectionIDs.contains($0) } ?? true) && (!pinnedOnly || clip.isPinned) && matchesDate
        }
    }
    private var selectedClip: Clip? { results.first { $0.id == selectedID } }
    private var sourceOptions: [String] { Array(Set(store.clips.map { $0.source.name })).sorted() }
    private var groups: [LibraryDayGroup] {
        let today = results.filter { Calendar.current.isDateInToday($0.lastCopiedAt) }, yesterday = results.filter { Calendar.current.isDateInYesterday($0.lastCopiedAt) }
        let earlier = results.filter { !Calendar.current.isDateInToday($0.lastCopiedAt) && !Calendar.current.isDateInYesterday($0.lastCopiedAt) }
        return [.init(key: "quick.today", clips: today), .init(key: "quick.yesterday", clips: yesterday), .init(key: "quick.earlier", clips: earlier)].filter { !$0.clips.isEmpty }
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            filterBar
            HStack { Text("library.itemCount \(results.count)", bundle: .module); Spacer() }
                .font(.system(size: 11)).foregroundStyle(MurinookPalette.soft).padding(.horizontal, 14).padding(.vertical, 6)
            if store.error != nil { MurinookErrorBanner(localizationKey: store.error!.localizationKey).padding(.horizontal, 14).padding(.top, 6) }
            if results.isEmpty {
                MurinookEmptyState(symbol: search.isEmpty ? "tray" : "magnifyingglass", title: packageText(search.isEmpty ? "quick.emptyTitle" : "quick.noResults"), message: packageText(search.isEmpty ? "quick.emptyMessage" : "quick.tryAnotherSearch")).frame(minHeight: 280)
            } else {
                HistoryPresentation(groups: groups, layout: layout, query: search, selectedIDs: Set([selectedID].compactMap { $0 }), focusedID: selectedID, ordinal: { clip in (results.firstIndex { $0.id == clip.id } ?? 0) + 1 }, select: activate, focus: { selectedID = $0.id }, contextMenu: { AnyView(clipMenu($0)) })
                    .onMoveCommand(perform: moveSelection)
                    .overlay(alignment: .topLeading) { numberedShortcuts }
            }
            actionBar
            footer
        }
        .frame(minWidth: 620, idealWidth: 750, maxWidth: .infinity, minHeight: 470, idealHeight: 570, maxHeight: .infinity).background(MurinookPalette.window)
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(MurinookPalette.border, lineWidth: 1))
        .shadow(color: MurinookPalette.shadow.opacity(0.2), radius: 28, x: 0, y: 12)
        .onExitCommand(perform: actions.close)
        .onAppear { if selectedID == nil { selectedID = results.first?.id } }
        .onChange(of: results.map(\.id)) { _, ids in if selectedID.map(ids.contains) != true { selectedID = ids.first } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { actions.close(); actions.openLibrary() } label: {
                HStack(spacing: 6) {
                    MurinookBrandMark(size: 22)
                    Text("Murinook").font(.system(size: 13, weight: .semibold)).foregroundStyle(MurinookPalette.text)
                }
                .padding(.horizontal, 5).padding(.vertical, 4)
                .background(isBrandHovered ? MurinookPalette.surface2 : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { isBrandHovered = $0 }
            .help(packageText("quick.library"))
            .accessibilityLabel(packageText("quick.library"))

            MurinookSearchField(text: $search, prompt: packageText("quick.search"), shortcut: Text("⌘ K"), focusOnAppear: true, focusShortcut: "k", moveSelection: moveSelection, submit: { plain in performPaste(plain: plain) }, cancel: actions.close)
            HistoryLayoutPicker(selection: Binding(get: { layout }, set: { value in preferences?.update { $0.historyLayout = value } }))
            captureButton
            Button { actions.close(); actions.openHistorySettings() } label: {
                Image(systemName: "gearshape").font(.system(size: 12, weight: .medium)).frame(width: 26, height: 26)
                    .background(isSettingsHovered ? MurinookPalette.surface2 : .clear, in: Circle())
            }
            .buttonStyle(.plain).foregroundStyle(MurinookPalette.muted)
            .onHover { isSettingsHovered = $0 }
            .help(packageText("quick.historySettings"))
            .accessibilityLabel(packageText("quick.historySettings"))
            Button(action: actions.close) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).frame(width: 26, height: 26)
            }
            .buttonStyle(.plain).foregroundStyle(MurinookPalette.muted)
            .help(packageText("common.close"))
            .accessibilityLabel(packageText("common.close"))
        }.padding(.horizontal, 16).frame(height: 55).background(MurinookPalette.surface).overlay(alignment: .bottom) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
    }
    private var captureButton: some View {
        let enabled = preferences?.value.captureEnabled ?? true
        return Button { preferences?.update { $0.captureEnabled.toggle() } } label: {
            HStack(spacing: 6) { Circle().fill(enabled ? MurinookPalette.accent : MurinookPalette.warm).frame(width: 7, height: 7); Text(enabled ? "quick.captureOn" : "quick.capturePaused", bundle: .module) }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(enabled ? MurinookPalette.accent : MurinookPalette.warm)
        }.buttonStyle(.plain).accessibilityLabel(packageText(enabled ? "quick.pauseCapture" : "quick.resumeCapture"))
    }
    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 5) {
                MurinookPill(title: packageText("filter.allKinds"), isSelected: kindFilter == nil) { kindFilter = nil }
                ForEach(ClipKind.allCases, id: \.self) { kind in MurinookPill(title: packageText("kind.\(kind.rawValue)"), isSelected: kindFilter == kind) { kindFilter = kind } }
                Rectangle().fill(MurinookPalette.border).frame(width: 1, height: 16).padding(.horizontal, 4)
                sourceMenu; dateMenu; collectionMenu
                MurinookPill(title: Text("library.pinned", bundle: .module), isSelected: pinnedOnly) { pinnedOnly.toggle() }
            }.padding(.horizontal, 14).padding(.vertical, 8)
        }.scrollIndicators(.hidden).background(MurinookPalette.surface).overlay(alignment: .bottom) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
    }
    private var sourceMenu: some View {
        Menu { Button { sourceFilter = nil } label: { Text("filter.anySource", bundle: .module) }; ForEach(sourceOptions, id: \.self) { name in Button(name) { sourceFilter = name } } } label: { menuChip(sourceFilter.map(Text.init) ?? packageText("filter.source"), selected: sourceFilter != nil) }.menuIndicator(.hidden)
    }
    private var dateMenu: some View {
        Menu { ForEach(["anytime", "today", "week", "month"], id: \.self) { value in Button { dateFilter = value } label: { packageText("filter.date.\(value)") } } } label: { menuChip(packageText("filter.date.\(dateFilter)"), selected: dateFilter != "anytime") }.menuIndicator(.hidden)
    }
    private var collectionMenu: some View {
        Menu { Button { collectionFilter = nil } label: { Text("library.allItems", bundle: .module) }; ForEach(store.collections) { item in Button(item.name) { collectionFilter = item.id } } } label: {
            menuChip(collectionFilter.flatMap { id in store.collections.first { $0.id == id }.map { Text($0.name) } } ?? packageText("library.collections"), selected: collectionFilter != nil)
        }.menuIndicator(.hidden)
    }
    private func menuChip(_ title: Text, selected: Bool) -> some View {
        HStack(spacing: 4) { title.font(.system(size: 11, weight: selected ? .semibold : .regular)).foregroundStyle(selected ? MurinookPalette.accent : MurinookPalette.muted); Image(systemName: "chevron.down").font(.system(size: 8)).foregroundStyle(MurinookPalette.soft) }.padding(.horizontal, 8).padding(.vertical, 5).background(selected ? MurinookPalette.accentSoft : Color.clear, in: Capsule())
    }
    private var actionBar: some View {
        HStack(spacing: 7) {
            Group { if let selectedClip { localizedClipTitle(selectedClip) } else { Text("quick.selectedItem", bundle: .module) } }.font(.system(size: 11, weight: .medium)).foregroundStyle(MurinookPalette.muted).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            if let clip = selectedClip {
                Button { actions.copy(clip) } label: { featureLabel("quick.copy", systemImage: "doc.on.doc") }.buttonStyle(MurinookButtonStyle(variant: .quiet))
                if clip.kind != .file && clip.kind != .image {
                    Button { performPaste(plain: true) } label: { featureLabel("quick.pastePlain", systemImage: "text.alignleft") }.buttonStyle(MurinookButtonStyle(variant: .quiet))
                }
                Button { Task { await store.togglePin(clip.id) } } label: { Image(systemName: clip.isPinned ? "pin.slash" : "pin") }.buttonStyle(MurinookButtonStyle(variant: .quiet)).help(packageText(clip.isPinned ? "library.unpin" : "library.pin"))
                Button { actions.addToShelf(clip) } label: { Image(systemName: "tray.and.arrow.down") }.buttonStyle(MurinookButtonStyle(variant: .quiet)).help(packageText("quick.addShelf"))
                Button { actions.addToQueue(clip) } label: { Image(systemName: "rectangle.stack") }.buttonStyle(MurinookButtonStyle(variant: .quiet)).help(packageText("quick.addQueue"))
            }
        }.padding(.horizontal, 14).frame(height: 45).background(MurinookPalette.surface).overlay(alignment: .top) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
    }
    private var footer: some View {
        HStack(spacing: 6) { Text("↑ ↓").murinookKeyCap(); Text("quick.select", bundle: .module); Text("↵").murinookKeyCap(); Text("quick.paste", bundle: .module); Text("⇧ ↵").murinookKeyCap(); Text("quick.pastePlain", bundle: .module); Spacer() }
            .font(.system(size: 11)).foregroundStyle(MurinookPalette.soft).padding(.horizontal, 14).frame(height: 36)
    }
    private var numberedShortcuts: some View {
        HStack { ForEach(0..<min(9, results.count), id: \.self) { index in Button("") { activate(results[index]) }.keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: []).accessibilityLabel(Text("quick.pasteNumber \(index + 1)", bundle: .module)) }.frame(width: 0, height: 0).hidden().accessibilityHidden(true) }
    }
    private func activate(_ clip: Clip) { selectedID = clip.id; actions.close(); actions.paste(clip) }
    private func performPaste(plain: Bool) { guard let selectedClip else { return }; performPaste(plain: plain, clip: selectedClip) }
    private func performPaste(plain: Bool, clip: Clip) { actions.close(); plain ? actions.pastePlain(clip) : actions.paste(clip) }
    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !results.isEmpty else { return }; let current = results.firstIndex { $0.id == selectedID } ?? 0
        let next = (direction == .down || direction == .right) ? min(current + 1, results.count - 1) : ((direction == .up || direction == .left) ? max(current - 1, 0) : current); selectedID = results[next].id
    }
    @ViewBuilder private func clipMenu(_ clip: Clip) -> some View {
        Button { performPaste(plain: false, clip: clip) } label: { Text("quick.paste", bundle: .module) }
        Button { actions.copy(clip) } label: { Text("quick.copy", bundle: .module) }
        if clip.kind != .file && clip.kind != .image { Button { performPaste(plain: true, clip: clip) } label: { Text("quick.pastePlain", bundle: .module) } }
        Divider()
        Button { actions.addToShelf(clip) } label: { Text("quick.addShelf", bundle: .module) }
        Button { actions.addToQueue(clip) } label: { Text("quick.addQueue", bundle: .module) }
        Button { Task { await store.togglePin(clip.id) } } label: { Text(clip.isPinned ? "library.unpin" : "library.pin", bundle: .module) }
    }
}

private extension View {
    func murinookKeyCap() -> some View { padding(.horizontal, 4).padding(.vertical, 2).background(MurinookPalette.surface2, in: RoundedRectangle(cornerRadius: 5)).overlay(RoundedRectangle(cornerRadius: 5).stroke(MurinookPalette.border, lineWidth: 1)) }
}
private func packageText(_ key: String) -> Text { Text(LocalizedStringKey(key), bundle: .module) }

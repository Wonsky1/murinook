import AppKit
import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI
import UniformTypeIdentifiers

struct LibraryDayGroup: Identifiable {
    let key: String
    let clips: [Clip]
    var id: String { key }
}

enum LibraryDateFilter: String, CaseIterable, Identifiable { case anytime, today, week, month; var id: String { rawValue } }

public struct LibraryView: View {
    let store: HistoryStore
    let actions: LibraryActions
    let preferences: PreferencesStore?
    let updates: UpdateStore?
    @Environment(\.locale) private var locale
    @State var query = ""
    @State var selectedIDs = Set<UUID>()
    @State var selectedCollectionID: UUID?
    @State var kind: ClipKind?
    @State var sourceName: String?
    @State var dateFilter: LibraryDateFilter = .anytime
    @State var showFilterBar = true
    @State var draftNote = ""
    @State var draftTags = ""
    @State var selectedContent: ClipContent?
    @State var showNewCollection = false
    @State var newCollectionName = ""
    @State var renamingCollectionID: UUID?
    @State var editedCollectionName = ""
    @State private var showDetails = false
    @State private var opensCollectionAfterDetails = false
    @State private var multiSelect = false
    @State private var selectionAnchorID: UUID?

    public init(store: HistoryStore, actions: LibraryActions, preferences: PreferencesStore? = nil, updates: UpdateStore? = nil) {
        self.store = store; self.actions = actions; self.preferences = preferences; self.updates = updates
    }

    private var layout: HistoryLayout { preferences?.value.historyLayout ?? .list }
    var sources: [String] { Array(Set(store.clips.map { $0.source.name })).sorted() }
    var filteredClips: [Clip] {
        store.clips.filter { clip in
            let textMatches = query.isEmpty || [clip.title, clip.searchText ?? clip.preview, clip.preview, clip.note, clip.source.name].contains { $0.localizedCaseInsensitiveContains(query) } || clip.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            let collectionMatches = selectedCollectionID.map { $0 == pinnedSelectionID ? clip.isPinned : clip.collectionIDs.contains($0) } ?? true
            let dateMatches: Bool = switch dateFilter {
            case .anytime: true
            case .today: Calendar.current.isDateInToday(clip.lastCopiedAt)
            case .week: clip.lastCopiedAt >= (Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast)
            case .month: clip.lastCopiedAt >= (Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .distantPast)
            }
            return textMatches && collectionMatches && (kind.map { clip.kind == $0 } ?? true) && (sourceName.map { clip.source.name == $0 } ?? true) && dateMatches
        }.sorted { $0.lastCopiedAt > $1.lastCopiedAt }
    }
    var selectedClip: Clip? {
        if let anchor = selectionAnchorID, selectedIDs.contains(anchor), let clip = filteredClips.first(where: { $0.id == anchor }) { return clip }
        return filteredClips.first { selectedIDs.contains($0.id) }
    }
    var selectedClips: [Clip] { store.clips.filter { selectedIDs.contains($0.id) } }
    var activeFilterCount: Int { (kind == nil ? 0 : 1) + (sourceName == nil ? 0 : 1) + (dateFilter == .anytime ? 0 : 1) }
    var dayGroups: [LibraryDayGroup] {
        let today = filteredClips.filter { Calendar.current.isDateInToday($0.lastCopiedAt) }
        let yesterday = filteredClips.filter { Calendar.current.isDateInYesterday($0.lastCopiedAt) }
        let earlier = filteredClips.filter { !Calendar.current.isDateInToday($0.lastCopiedAt) && !Calendar.current.isDateInYesterday($0.lastCopiedAt) }
        return [LibraryDayGroup(key: "library.day.today", clips: today), .init(key: "library.day.yesterday", clips: yesterday), .init(key: "library.day.earlier", clips: earlier)].filter { !$0.clips.isEmpty }
    }

    public var body: some View {
        VStack(spacing: 0) {
            windowToolbar
            if case .available(let release) = updates?.state {
                LibraryUpdateBanner(version: release.version.description, showUpdates: actions.showUpdates)
            }
            Rectangle().fill(MurinookPalette.border).frame(height: 1)
            collectionBar
            focusPreview
            if showFilterBar { filterBar }
            if store.error != nil { MurinookErrorBanner(localizationKey: store.error!.localizationKey).padding(.horizontal, 18).padding(.vertical, 8) }
            historyHeader
            if filteredClips.isEmpty {
                MurinookEmptyState(symbol: query.isEmpty ? "tray" : "magnifyingglass", title: libraryText(query.isEmpty ? "library.emptyTitle" : "quick.noResults"), message: libraryText(query.isEmpty ? "library.emptyMessage" : "quick.tryAnotherSearch"))
            } else {
                HistoryPresentation(groups: dayGroups, layout: layout, query: query, selectedIDs: selectedIDs, focusedID: selectedClip?.id,
                    ordinal: { clip in filteredClips.firstIndex(where: { $0.id == clip.id }).map { $0 + 1 } },
                    select: selectClip, focus: focusClip, contextMenu: { AnyView(contextMenu(for: $0)) })
                    .onKeyPress(.return, phases: .down) { press in
                        guard let selectedClip else { return .ignored }
                        if press.modifiers.contains(.shift) {
                            guard selectedClip.kind != .file && selectedClip.kind != .image else { return .handled }
                            actions.pastePlain(selectedClip)
                        } else { actions.paste(selectedClip) }
                        return .handled
                    }
            }
            if selectedIDs.count > 1 { bulkActionBar }
            footer
        }
        .frame(minWidth: 780, minHeight: 600).background(MurinookPalette.window)
        .onChange(of: selectedClip?.id) { _, _ in loadDrafts() }
        .onChange(of: filteredClips.map(\.id)) { _, ids in
            selectedIDs.formIntersection(Set(ids))
            if selectedIDs.isEmpty, let first = ids.first { selectedIDs = [first] }
        }
        .onMoveCommand(perform: moveLibrarySelection)
        .task(id: selectedClip?.contentID) { await loadSelectedContent(for: selectedClip) }
        .onAppear { if selectedIDs.isEmpty, let first = filteredClips.first { selectedIDs = [first.id] }; loadDrafts() }
        .sheet(isPresented: $showNewCollection) { collectionSheet }
        .sheet(isPresented: Binding(get: { renamingCollectionID != nil }, set: { if !$0 { renamingCollectionID = nil } })) { renameSheet }
        .sheet(isPresented: $showDetails, onDismiss: {
            loadDrafts()
            if opensCollectionAfterDetails { opensCollectionAfterDetails = false; showNewCollection = true }
        }) { detailsSheet }
    }

    private var collectionBar: some View {
        HStack(spacing: 7) {
            collectionChip("library.allItems", selected: selectedCollectionID == nil) { selectedCollectionID = nil }
            collectionChip("library.pinned", selected: selectedCollectionID == pinnedSelectionID) { selectedCollectionID = pinnedSelectionID }
            ScrollView(.horizontal) {
                HStack(spacing: 5) {
                    ForEach(store.collections) { collection in
                        Button { selectedCollectionID = collection.id } label: {
                            HStack(spacing: 5) { Circle().fill(collectionColor(collection.colorHex)).frame(width: 7, height: 7); Text(collection.name).lineLimit(1) }
                                .font(.system(size: 11, weight: selectedCollectionID == collection.id ? .semibold : .regular))
                                .foregroundStyle(selectedCollectionID == collection.id ? MurinookPalette.accent : MurinookPalette.muted)
                                .padding(.horizontal, 10).frame(height: 27).background(selectedCollectionID == collection.id ? MurinookPalette.accentSoft : Color.clear, in: Capsule())
                        }.buttonStyle(.plain).contextMenu {
                            Button { editedCollectionName = collection.name; renamingCollectionID = collection.id } label: { Text("library.renameCollection", bundle: .module) }
                            Button(role: .destructive) { Task { await store.removeCollection(collection.id) } } label: { Text("library.deleteCollection", bundle: .module) }
                        }
                    }
                }
            }.scrollIndicators(.hidden)
            Button { showNewCollection = true } label: { Image(systemName: "plus") }.buttonStyle(MurinookButtonStyle(variant: .quiet)).help(libraryText("library.newCollection")).accessibilityLabel(libraryText("library.newCollection"))
            Button { actions.showShelf() } label: { Image(systemName: "tray.full") }.buttonStyle(MurinookButtonStyle(variant: .quiet)).help(libraryText("library.showShelf"))
        }.padding(.horizontal, 18).padding(.vertical, 7)
    }

    private func collectionChip(_ key: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(LocalizedStringKey(key), bundle: .module).font(.system(size: 11, weight: selected ? .semibold : .regular)).foregroundStyle(selected ? MurinookPalette.accent : MurinookPalette.muted).padding(.horizontal, 10).frame(height: 27).background(selected ? MurinookPalette.accentSoft : Color.clear, in: Capsule()) }.buttonStyle(.plain)
    }

    private var focusPreview: some View {
        Group {
            if let clip = selectedClip {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(alignment: .center, spacing: 22) {
                        focusObject(clip).frame(width: 230, height: 175)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(clip.source.name); Text("·")
                                Text(clip.lastCopiedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(locale)))
                                Text("·"); libraryText("kind." + clip.kind.rawValue)
                                if clip.isPinned { Image(systemName: "pin.fill").foregroundStyle(MurinookPalette.accent).accessibilityLabel(libraryText("library.pinned")) }
                            }.font(.system(size: 11)).foregroundStyle(MurinookPalette.soft)
                            localizedClipTitle(clip).font(.system(size: 25, weight: .medium)).tracking(-0.7).foregroundStyle(MurinookPalette.text).lineLimit(2)
                            Text(Int64(clip.byteCount), format: .byteCount(style: .file)).font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
                            HStack(spacing: 7) {
                                Button { actions.paste(clip) } label: { featureLabel("quick.paste", systemImage: "return") }.buttonStyle(MurinookButtonStyle(variant: .primary))
                                Button { actions.copy(clip) } label: { featureLabel("quick.copy", systemImage: "doc.on.doc") }.buttonStyle(MurinookButtonStyle(variant: .quiet))
                                Button { actions.addToShelf(clip) } label: { Image(systemName: "tray.and.arrow.down") }.buttonStyle(MurinookButtonStyle(variant: .quiet)).help(libraryText("quick.addShelf"))
                                Button { actions.addToQueue(clip) } label: { Image(systemName: "rectangle.stack") }.buttonStyle(MurinookButtonStyle(variant: .quiet)).help(libraryText("quick.addQueue"))
                                Button { Task { await store.togglePin(clip.id) } } label: { Image(systemName: clip.isPinned ? "pin.slash" : "pin") }.buttonStyle(MurinookButtonStyle(variant: .quiet)).help(libraryText(clip.isPinned ? "library.unpin" : "library.pin"))
                                Button { loadDrafts(); showDetails = true } label: { Image(systemName: "slider.horizontal.3") }.buttonStyle(MurinookButtonStyle(variant: .quiet)).help(libraryText("library.details"))
                            }.padding(.top, 6)
                            HStack(spacing: 13) {
                                if clip.kind != .file && clip.kind != .image { Button { actions.pastePlain(clip) } label: { libraryText("quick.pastePlain") }.buttonStyle(.plain) }
                                Button { actions.preview(clip) } label: { libraryText("library.preview") }.buttonStyle(.plain)
                                if clip.kind == .file { Button { actions.reveal(clip) } label: { libraryText("library.reveal") }.buttonStyle(.plain) }
                                Button(role: .destructive) { Task { await store.remove([clip.id]); selectedIDs.remove(clip.id) } } label: { libraryText("library.remove") }.buttonStyle(.plain)
                            }.font(.system(size: 11)).foregroundStyle(MurinookPalette.muted).padding(.top, 2)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(18).background(MurinookPalette.surface, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(MurinookPalette.border, lineWidth: 1))
                .padding(.horizontal, 22).padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder private func focusObject(_ clip: Clip) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [MurinookPalette.surface2, MurinookPalette.window], startPoint: .topLeading, endPoint: .bottomTrailing))
            if clip.kind == .image,
               let data = selectedContent?.representations.first(where: { UTType($0.typeIdentifier)?.conforms(to: .image) == true })?.data,
               let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFit().padding(10)
            } else if clip.kind == .file {
                VStack(spacing: 9) {
                    MurinookContentIcon(data: clip.iconData ?? selectedContent?.iconData, kindIdentifier: clip.kind.rawValue, symbol: clip.kind.symbolName, size: 82)
                    Text(clip.title).font(.system(size: 11, weight: .medium)).lineLimit(2).multilineTextAlignment(.center).foregroundStyle(MurinookPalette.text)
                }.padding(16)
            } else {
                ScrollView { Text(clip.preview.isEmpty ? clip.title : clip.preview).font(clip.kind == .code ? .system(size: 12, design: .monospaced) : .system(size: 12)).foregroundStyle(MurinookPalette.text).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }.padding(14)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityLabel(libraryText("library.preview"))
    }

    private var historyHeader: some View {
        HStack {
            Text("library.itemCount \(filteredClips.count)", bundle: .module).font(.system(size: 11)).foregroundStyle(MurinookPalette.soft)
            Spacer()
            Button { showFilterBar.toggle() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "line.3.horizontal.decrease")
                    libraryText("library.filters")
                    if activeFilterCount > 0 { Text("\(activeFilterCount)").monospacedDigit() }
                }
            }.buttonStyle(MurinookButtonStyle(variant: .quiet))
            Button { multiSelect.toggle(); if !multiSelect, selectedIDs.count > 1 { selectedIDs = Set(selectedClip.map { [$0.id] } ?? []) } } label: { featureLabel("library.multiSelect", systemImage: multiSelect ? "checklist" : "list.bullet") }.buttonStyle(MurinookButtonStyle(variant: .quiet)).help(libraryText("library.multiSelect"))
        }.padding(.horizontal, 20).padding(.vertical, 5)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) { Circle().fill(MurinookPalette.accent).frame(width: 7, height: 7); Text("library.localHistory", bundle: .module) }
            Spacer()
            if let preferences {
                Button { actions.manageRetention() } label: {
                    HStack(spacing: 4) {
                        libraryText("library.retention.\(preferences.value.retentionDays)")
                        Text("·")
                        if preferences.value.maxHistoryItems == 0 {
                            libraryText("library.retention.unlimitedItems")
                        } else {
                            Text("library.retention.itemLimit \(preferences.value.maxHistoryItems.formatted(.number.locale(locale)))", bundle: .module)
                        }
                    }
                }.buttonStyle(.plain).foregroundStyle(MurinookPalette.muted)
            }
            Button { actions.export(Set(filteredClips.map(\.id))) } label: { Image(systemName: "square.and.arrow.up") }.buttonStyle(MurinookButtonStyle(variant: .quiet)).help(libraryText("library.export"))
            Button { actions.showSettings() } label: { Image(systemName: "gearshape") }.buttonStyle(MurinookButtonStyle(variant: .quiet)).help(libraryText("library.showSettings"))
        }.font(.system(size: 11)).padding(.horizontal, 18).frame(height: 38).background(MurinookPalette.surface)
    }

    var bulkActionBar: some View {
        HStack(spacing: 10) {
            Text("library.selectedCount \(selectedIDs.count)", bundle: .module).font(.system(size: 11)); Spacer()
            Button { selectedClips.forEach(actions.addToShelf) } label: { Image(systemName: "tray") }.help(libraryText("quick.addShelf"))
            Button { selectedClips.forEach(actions.addToQueue) } label: { Image(systemName: "rectangle.stack") }.help(libraryText("quick.addQueue"))
            Button { actions.export(selectedIDs) } label: { Image(systemName: "square.and.arrow.up") }.help(libraryText("library.export"))
            Button { Task { await store.remove(selectedIDs); selectedIDs.removeAll() } } label: { Image(systemName: "trash") }.help(libraryText("library.remove"))
            Button { Task { await store.undoRemoval() } } label: { Image(systemName: "arrow.uturn.backward") }.help(libraryText("library.undo"))
        }.buttonStyle(.plain).foregroundStyle(MurinookPalette.accent).padding(.horizontal, 19).frame(height: 42).background(MurinookPalette.surface).overlay(alignment: .top) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
    }

    private var detailsSheet: some View {
        VStack(spacing: 0) {
            HStack {
                libraryText("library.details").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { showDetails = false } label: { Image(systemName: "xmark").frame(width: 26, height: 26) }
                    .buttonStyle(.plain).accessibilityLabel(libraryText("common.close"))
            }.padding(.horizontal, 17).padding(.vertical, 10).background(MurinookPalette.surface)
            LibraryInspector(clip: selectedClip, content: selectedContent, store: store, actions: actions, selectedIDs: $selectedIDs, draftNote: $draftNote, draftTags: $draftTags, query: query, addCollection: { opensCollectionAfterDetails = true; showDetails = false })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(width: 390, height: 610).background(MurinookPalette.window)
    }

    var pinnedSelectionID: UUID { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! }
    func loadDrafts() { draftNote = selectedClip?.note ?? ""; draftTags = selectedClip?.tags.joined(separator: ", ") ?? "" }
    func loadSelectedContent(for clip: Clip?) async {
        guard let clip, clip.kind != .file else { selectedContent = nil; return }
        let content = await actions.loadContent(clip.contentID)
        guard !Task.isCancelled, selectedClip?.contentID == clip.contentID else { return }
        selectedContent = content
    }
    private func moveLibrarySelection(_ direction: MoveCommandDirection) {
        guard !filteredClips.isEmpty else { return }
        let focused = selectionAnchorID ?? selectedClip?.id
        let current = filteredClips.firstIndex { $0.id == focused } ?? 0
        let next: Int
        switch direction { case .down, .right: next = min(current + 1, filteredClips.count - 1); case .up, .left: next = max(current - 1, 0); default: return }
        if multiSelect || NSEvent.modifierFlags.contains(.shift) { selectedIDs.insert(filteredClips[next].id) } else { selectedIDs = [filteredClips[next].id] }
        selectionAnchorID = filteredClips[next].id
    }

    private func focusClip(_ clip: Clip) {
        if multiSelect { selectedIDs.insert(clip.id) } else { selectedIDs = [clip.id] }
        selectionAnchorID = clip.id
    }

    private func selectClip(_ clip: Clip) {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.shift), let anchor = selectionAnchorID,
           let start = filteredClips.firstIndex(where: { $0.id == anchor }),
           let end = filteredClips.firstIndex(where: { $0.id == clip.id }) {
            let rangeIDs = Set(filteredClips[min(start, end)...max(start, end)].map(\.id))
            if modifiers.contains(.command) || multiSelect { selectedIDs.formUnion(rangeIDs) }
            else { selectedIDs = rangeIDs }
        } else if modifiers.contains(.command) || multiSelect {
            if selectedIDs.contains(clip.id) { selectedIDs.remove(clip.id) } else { selectedIDs.insert(clip.id) }
            selectionAnchorID = clip.id
        } else {
            selectedIDs = [clip.id]
            selectionAnchorID = clip.id
        }
    }
}

func collectionColor(_ hex: String) -> Color {
    let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x818CF8
    return Color(.sRGB, red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255, opacity: 1)
}
func libraryText(_ key: String) -> Text { Text(LocalizedStringKey(key), bundle: .module) }
func featureLabel(_ key: String, systemImage: String) -> some View { Label { Text(LocalizedStringKey(key), bundle: .module) } icon: { Image(systemName: systemImage) } }

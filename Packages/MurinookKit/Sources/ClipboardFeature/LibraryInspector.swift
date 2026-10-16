import AppKit
import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI
import UniformTypeIdentifiers

struct LibraryInspector: View {
    let clip: Clip?
    let content: ClipContent?
    let store: HistoryStore
    let actions: LibraryActions
    @Binding var selectedIDs: Set<UUID>
    @Binding var draftNote: String
    @Binding var draftTags: String
    let query: String
    let addCollection: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if let clip {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        preview(for: clip)
                        localizedClipTitle(clip).font(.system(size: 15, weight: .semibold)).textSelection(.enabled)
                        VStack(alignment: .leading, spacing: 8) {
                            metadata("library.source", Text(clip.source.name))
                            metadata("library.kind", text("kind.\(clip.kind.rawValue)"))
                            metadata("library.copied", Text(clip.lastCopiedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(locale))))
                            metadata("library.size", Text(Int64(clip.byteCount), format: .byteCount(style: .file)))
                        }
                        HStack(spacing: 8) {
                            Button { actions.paste(clip) } label: { text("quick.paste").frame(maxWidth: .infinity) }
                                .buttonStyle(MurinookButtonStyle(variant: .primary))
                            Button { actions.copy(clip) } label: { Label { text("quick.copy") } icon: { Image(systemName: "doc.on.doc") } }
                                .buttonStyle(MurinookButtonStyle())
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            action("quick.addShelf", "tray") { actions.addToShelf(clip) }
                            action("quick.addQueue", "rectangle.stack") { actions.addToQueue(clip) }
                            action(clip.isPinned ? "library.unpin" : "library.pin", "pin") { Task { await store.togglePin(clip.id) } }
                            action("library.preview", "eye") { actions.preview(clip) }
                            if clip.kind == .file { action("library.reveal", "folder") { actions.reveal(clip) } }
                            if clip.kind != .file && clip.kind != .image {
                                action("quick.pastePlain", "text.alignleft") { actions.pastePlain(clip) }
                            }
                            Button(role: .destructive) { Task { await store.remove(selectedIDs); selectedIDs.removeAll() } } label: {
                                Label { text("library.remove") } icon: { Image(systemName: "trash").frame(width: 16) }
                            }.font(.system(size: 11)).buttonStyle(.plain)
                        }.padding(.vertical, 3)
                        Divider().overlay(MurinookPalette.border)
                        Menu {
                            ForEach(store.collections) { collection in
                                Toggle(isOn: Binding(get: { clip.collectionIDs.contains(collection.id) }, set: { included in
                                    Task { await store.setCollection(selectedIDs, collectionID: collection.id, included: included) }
                                })) { Text(collection.name) }
                            }
                            Button(action: addCollection) { text("library.newCollection") }
                        } label: { text("library.addToCollection") }
                            .font(.system(size: 11)).foregroundStyle(MurinookPalette.accent)
                        ForEach(store.collections.filter { clip.collectionIDs.contains($0.id) }) { collection in
                            Text(collection.name).font(.system(size: 11, weight: .medium)).foregroundStyle(MurinookPalette.accent)
                                .padding(.horizontal, 7).padding(.vertical, 4)
                                .background(MurinookPalette.accentSoft, in: RoundedRectangle(cornerRadius: 5))
                        }
                        text("library.note").font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(MurinookPalette.soft)
                        TextEditor(text: $draftNote).font(.system(size: 11)).scrollContentBackground(.hidden)
                            .frame(minHeight: 68).padding(5).background(MurinookPalette.surface2, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(MurinookPalette.border, lineWidth: 1))
                            .accessibilityLabel(text("library.note"))
                        TextField(text: $draftTags, prompt: text("library.tags")) { EmptyView() }
                            .textFieldStyle(.roundedBorder).font(.system(size: 11)).accessibilityLabel(text("library.tags"))
                        Button { save(clip) } label: { text("library.saveDetails") }
                            .buttonStyle(MurinookButtonStyle()).frame(maxWidth: .infinity, alignment: .trailing)
                    }.padding(16)
                }
            } else {
                MurinookEmptyState(symbol: "sidebar.right", title: text("library.selectItem"), message: text("library.selectItemMessage"))
            }
        }.foregroundStyle(MurinookPalette.text).frame(maxHeight: .infinity)
            .background(MurinookPalette.surface)
            .overlay(alignment: .leading) { Rectangle().fill(MurinookPalette.border).frame(width: 1) }
    }

    @ViewBuilder private func preview(for clip: Clip) -> some View {
        if clip.kind == .image,
           let data = content?.representations.first(where: { UTType($0.typeIdentifier)?.conforms(to: .image) == true })?.data,
           let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 164)
                .padding(8).background(MurinookPalette.surface2, in: RoundedRectangle(cornerRadius: 9))
                .accessibilityLabel(text("library.imagePreview"))
        } else {
            ScrollView {
                MurinookHighlightedText(content?.plainText ?? clip.searchText ?? (clip.preview.isEmpty ? clip.title : clip.preview), query: query)
                    .font(clip.kind == .code ? .system(size: 11, design: .monospaced) : .system(size: 11))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading).padding(12)
            }.frame(height: 164)
                .background(LinearGradient(colors: [MurinookPalette.accentSoft, MurinookPalette.surface2], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityLabel(text("library.preview"))
        }
    }

    private func action(_ key: String, _ symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) { Label { text(key) } icon: { Image(systemName: symbol).frame(width: 16) } }
            .font(.system(size: 11)).foregroundStyle(MurinookPalette.accent).buttonStyle(.plain)
    }
    private func metadata(_ key: String, _ value: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            text(key).foregroundStyle(MurinookPalette.soft).frame(width: 70, alignment: .leading)
            value.foregroundStyle(MurinookPalette.muted).lineLimit(2).textSelection(.enabled)
        }.font(.system(size: 11))
    }
    private func save(_ clip: Clip) {
        let tags = draftTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let note = draftNote
        Task { await store.updateDetails(clip.id, note: note, tags: tags) }
    }
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), bundle: .module) }
}

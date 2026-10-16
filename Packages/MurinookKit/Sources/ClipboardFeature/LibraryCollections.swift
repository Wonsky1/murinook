import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

extension LibraryView {
    var collectionSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("library.newCollection", bundle: .module).font(.title2.bold())
            TextField(text: $newCollectionName, prompt: Text("library.collectionName", bundle: .module)) { EmptyView() }
            HStack {
                Spacer()
                Button { showNewCollection = false } label: { Text("common.cancel", bundle: .module) }
                Button {
                    let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { Task { await store.addCollection(name: name, colorHex: "#3D806C") } }
                    showNewCollection = false
                } label: { Text("common.create", bundle: .module) }
                    .buttonStyle(MurinookButtonStyle(variant: .primary)).disabled(newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }.padding(24).frame(width: 340)
    }

    var renameSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("library.renameCollection", bundle: .module).font(.title2.bold())
            TextField(text: $editedCollectionName, prompt: Text("library.collectionName", bundle: .module)) { EmptyView() }
            HStack {
                Spacer()
                Button { renamingCollectionID = nil } label: { Text("common.cancel", bundle: .module) }
                Button {
                    if let id = renamingCollectionID {
                        Task { await store.renameCollection(id, name: editedCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    }
                    renamingCollectionID = nil
                } label: { Text("common.save", bundle: .module) }
                    .buttonStyle(MurinookButtonStyle(variant: .primary)).disabled(editedCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width: 340)
    }

    func contextMenu(for clip: Clip) -> some View {
        Group {
            Button { actions.copy(clip) } label: { Text("quick.copy", bundle: .module) }
            if clip.kind != .file && clip.kind != .image { Button { actions.pastePlain(clip) } label: { Text("quick.pastePlain", bundle: .module) } }
            Button { actions.paste(clip) } label: { Text("quick.paste", bundle: .module) }
            Button { Task { await store.togglePin(clip.id) } } label: { Text(clip.isPinned ? "library.unpin" : "library.pin", bundle: .module) }
            Divider()
            Button { actions.addToShelf(clip) } label: { Text("quick.addShelf", bundle: .module) }
            Button { actions.addToQueue(clip) } label: { Text("quick.addQueue", bundle: .module) }
            Button { actions.preview(clip) } label: { Text("library.preview", bundle: .module) }
            if clip.kind == .file { Button { actions.reveal(clip) } label: { Text("library.reveal", bundle: .module) } }
            Button(role: .destructive) { Task { await store.remove([clip.id]) } } label: { Text("library.remove", bundle: .module) }
        }
    }

}

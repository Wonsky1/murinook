import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

extension LibraryView {
    var windowToolbar: some View {
        HStack(spacing: 10) {
            MurinookWindowControls()
            MurinookBrandMark(size: 19)
            Text("Murinook").font(.system(size: 12, weight: .semibold)).foregroundStyle(MurinookPalette.text)
            MurinookSearchField(text: $query, prompt: libraryText("library.search"), shortcut: Text("⌘ F"), focusShortcut: "f")
                .frame(maxWidth: 360).frame(maxWidth: .infinity)
            HistoryLayoutPicker(selection: Binding(get: { preferences?.value.historyLayout ?? .list }, set: { value in preferences?.update { $0.historyLayout = value } }))
            if let preferences {
                Button { preferences.update { $0.captureEnabled.toggle() } } label: {
                    HStack(spacing: 5) {
                        Circle().fill(preferences.value.captureEnabled ? MurinookPalette.accent : MurinookPalette.warm).frame(width: 7, height: 7)
                        Text(preferences.value.captureEnabled ? "quick.captureOn" : "quick.capturePaused", bundle: .module)
                    }.font(.system(size: 11, weight: .medium)).foregroundStyle(MurinookPalette.muted)
                }.buttonStyle(.plain).accessibilityLabel(libraryText(preferences.value.captureEnabled ? "quick.pauseCapture" : "quick.resumeCapture"))
            }
            Button(action: actions.showSettings) { Image(systemName: "gearshape") }.buttonStyle(.plain).foregroundStyle(MurinookPalette.muted).help(libraryText("library.showSettings"))
            Menu { moreMenu } label: { Image(systemName: "ellipsis").font(.system(size: 14, weight: .medium)) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).foregroundStyle(MurinookPalette.muted)
        }
        .padding(.horizontal, 15).frame(height: 50).background(MurinookPalette.surface)
    }

    @ViewBuilder var moreMenu: some View {
        if !selectedIDs.isEmpty {
            Button { Task { for clip in selectedClips { await store.togglePin(clip.id) } } } label: {
                Text(selectedClips.allSatisfy(\.isPinned) ? "library.unpin" : "library.pin", bundle: .module)
            }
            Button { selectedClips.forEach(actions.addToShelf) } label: { Text("quick.addShelf", bundle: .module) }
            Button { selectedClips.forEach(actions.addToQueue) } label: { Text("quick.addQueue", bundle: .module) }
            if selectedClips.count == 1, let clip = selectedClips.first {
                Button { actions.copy(clip) } label: { Text("quick.copy", bundle: .module) }
                Button { actions.paste(clip) } label: { Text("quick.paste", bundle: .module) }
                if clip.kind == .file { Button { actions.reveal(clip) } label: { Text("library.reveal", bundle: .module) } }
            }
            Button { actions.export(selectedIDs) } label: { Text("library.export", bundle: .module) }
            Button(role: .destructive) { Task { await store.remove(selectedIDs); selectedIDs.removeAll() } } label: { Text("library.remove", bundle: .module) }
            Divider()
        }
        Button(action: actions.showShelf) { Text("library.showShelf", bundle: .module) }
        Button(action: actions.showSettings) { Text("library.showSettings", bundle: .module) }
        Button { Task { await store.undoRemoval() } } label: { Text("library.undo", bundle: .module) }
    }

}

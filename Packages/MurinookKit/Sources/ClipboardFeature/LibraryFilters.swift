import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

extension LibraryView {
    var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                MurinookPill(title: libraryText("filter.allKinds"), isSelected: kind == nil) { kind = nil }
                ForEach(ClipKind.allCases, id: \.self) { item in
                    MurinookPill(title: libraryText("kind.\(item.rawValue)"), isSelected: kind == item) { kind = item }
                }
                Rectangle().fill(MurinookPalette.border).frame(width: 1, height: 16).padding(.horizontal, 5)
                sourceMenu
                dateMenu
            }
            .padding(.horizontal, 18).padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .top) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
    }

    var sourceMenu: some View {
        Menu {
            Button { sourceName = nil } label: { Text("filter.anySource", bundle: .module) }
            ForEach(sources, id: \.self) { source in Button(source) { sourceName = source } }
        } label: { menuChip(sourceName.map(Text.init) ?? libraryText("filter.source"), selected: sourceName != nil) }
        .menuIndicator(.hidden)
    }

    var dateMenu: some View {
        Menu {
            ForEach(LibraryDateFilter.allCases) { item in
                Button { dateFilter = item } label: { libraryText("filter.date.\(item.rawValue)") }
            }
        } label: { menuChip(libraryText("filter.date.\(dateFilter.rawValue)"), selected: dateFilter != .anytime) }
        .menuIndicator(.hidden)
    }

    func menuChip(_ title: Text, selected: Bool) -> some View {
        HStack(spacing: 4) {
            title.font(.system(size: 11, weight: selected ? .semibold : .regular)).foregroundStyle(selected ? MurinookPalette.accent : MurinookPalette.muted)
            Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(MurinookPalette.soft)
        }.padding(.horizontal, 8).padding(.vertical, 5)
            .background(selected ? MurinookPalette.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 7))
    }

}

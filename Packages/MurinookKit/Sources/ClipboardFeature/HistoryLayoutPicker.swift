import MurinookDesignSystem
import MurinookDomain
import SwiftUI

struct HistoryLayoutPicker: View {
    @Binding var selection: HistoryLayout
    var body: some View {
        HStack(spacing: 2) {
            layoutButton(.grid, symbol: "square.grid.2x2", title: "history.layout.grid")
            layoutButton(.list, symbol: "list.bullet", title: "history.layout.list")
            layoutButton(.strip, symbol: "rectangle.split.3x1", title: "history.layout.strip")
        }
        .padding(3).background(MurinookPalette.surface2, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(MurinookPalette.border, lineWidth: 1))
    }
    private func layoutButton(_ layout: HistoryLayout, symbol: String, title: String) -> some View {
        Button { selection = layout } label: {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium)).frame(width: 27, height: 25)
                .foregroundStyle(selection == layout ? MurinookPalette.text : MurinookPalette.soft)
                .background(selection == layout ? MurinookPalette.surface : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain).help(Text(LocalizedStringKey(title), bundle: .module)).accessibilityLabel(Text(LocalizedStringKey(title), bundle: .module)).accessibilityAddTraits(selection == layout ? .isSelected : [])
    }
}

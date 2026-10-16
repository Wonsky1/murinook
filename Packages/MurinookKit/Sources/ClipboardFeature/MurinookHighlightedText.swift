import MurinookDesignSystem
import SwiftUI

struct MurinookHighlightedText: View {
    let value: String
    let query: String

    init(_ value: String, query: String) { self.value = value; self.query = query }

    var body: some View { Text(attributedValue) }

    private var attributedValue: AttributedString {
        var attributed = AttributedString(value)
        guard !query.isEmpty else { return attributed }
        var searchRange = value.startIndex..<value.endIndex
        while let match = value.range(of: query, options: .caseInsensitive, range: searchRange) {
            if let attributedRange = Range(match, in: attributed) {
                attributed[attributedRange].foregroundColor = MurinookPalette.accent
                attributed[attributedRange].backgroundColor = MurinookPalette.accentSoft
            }
            searchRange = match.upperBound..<value.endIndex
        }
        return attributed
    }
}

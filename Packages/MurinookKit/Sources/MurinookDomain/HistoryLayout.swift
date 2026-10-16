/// Presentation preference shared by Library and Quick Access. It never changes
/// the history query or clipboard behavior.
public enum HistoryLayout: String, Codable, CaseIterable, Sendable {
    case grid, list, strip
}

import Foundation

/// Shared compact shelf dimensions used by the shelf UI and its hosting panel.
public enum ShelfLayout {
    public static let width: CGFloat = 260
    public static let minimumHeight: CGFloat = 112
    public static let maximumHeight: CGFloat = 320
    public static let rowHeight: CGFloat = 45
    private static let contentChromeHeight: CGFloat = 58

    public static func height(for itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return minimumHeight }
        return min(maximumHeight, max(minimumHeight, contentChromeHeight + CGFloat(itemCount) * rowHeight))
    }
}

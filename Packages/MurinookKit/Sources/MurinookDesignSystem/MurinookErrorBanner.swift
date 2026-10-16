import AppKit
import SwiftUI

public struct MurinookErrorBanner: View {
    public let localizationKey: String
    public init(localizationKey: String) { self.localizationKey = localizationKey }
    public var body: some View {
        Label { Text(LocalizedStringKey(localizationKey), bundle: .module) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
            .font(.system(size: 12)).foregroundStyle(MurinookPalette.warm)
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(MurinookPalette.warm.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

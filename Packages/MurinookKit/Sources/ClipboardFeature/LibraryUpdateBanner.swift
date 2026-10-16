import MurinookDesignSystem
import SwiftUI

struct LibraryUpdateBanner: View {
    let version: String
    let showUpdates: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(MurinookPalette.accent)
                .accessibilityHidden(true)
            Text("library.updateAvailable \(version)", bundle: .module)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MurinookPalette.text)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button(action: showUpdates) {
                Text("library.viewUpdate", bundle: .module)
            }
            .buttonStyle(MurinookButtonStyle(variant: .quiet))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .background(MurinookPalette.accentSoft.opacity(0.45))
        .accessibilityElement(children: .contain)
    }
}

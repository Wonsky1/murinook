import MurinookDesignSystem
import SwiftUI

public struct BackgroundRunningView: View {
    private let dismiss: () -> Void

    public init(dismiss: @escaping () -> Void) {
        self.dismiss = dismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                MurinookBrandMark(size: 24)
                Text("Murinook")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MurinookPalette.text)
                Spacer(minLength: 0)
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(MurinookPalette.muted)
                .accessibilityLabel(Text("backgroundRunning.close", bundle: .module))
                .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("backgroundRunning.title", bundle: .module)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .tracking(-0.25)
                    .foregroundStyle(MurinookPalette.text)
                Text("backgroundRunning.message", bundle: .module)
                    .font(.system(size: 12))
                    .lineSpacing(2)
                    .foregroundStyle(MurinookPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Text("backgroundRunning.quitPath", bundle: .module)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MurinookPalette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: dismiss) {
                    Text("backgroundRunning.gotIt", bundle: .module)
                }
                .buttonStyle(MurinookButtonStyle(variant: .primary))
                .keyboardShortcut(.defaultAction)
            }
            .padding(11)
            .background(MurinookPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MurinookPalette.border, lineWidth: 1))
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(MurinookPalette.window)
        .onExitCommand(perform: dismiss)
    }
}

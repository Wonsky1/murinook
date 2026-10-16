import MurinookDesignSystem
import SwiftUI

public struct BackgroundRunningView: View {
    private let dismiss: () -> Void

    public init(dismiss: @escaping () -> Void) {
        self.dismiss = dismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                MurinookWindowControls()
                MurinookBrandMark(size: 22)
                Text("Murinook")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MurinookPalette.muted)
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 48)

            VStack(alignment: .leading, spacing: 0) {
                Text("backgroundRunning.title", bundle: .module)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .tracking(-0.45)
                    .foregroundStyle(MurinookPalette.text)
                Text("backgroundRunning.message", bundle: .module)
                    .font(.system(size: 12))
                    .lineSpacing(3)
                    .foregroundStyle(MurinookPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 9)

                HStack(alignment: .top, spacing: 10) {
                    MurinookBrandMark(size: 26)
                    Text("backgroundRunning.quitPath", bundle: .module)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MurinookPalette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MurinookPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MurinookPalette.border, lineWidth: 1))
                .padding(.top, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 25)

            HStack {
                Spacer()
                Button(action: dismiss) {
                    Text("backgroundRunning.gotIt", bundle: .module)
                }
                .buttonStyle(MurinookButtonStyle(variant: .primary))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .frame(height: 58)
            .overlay(alignment: .top) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
        }
        .frame(minWidth: 400, minHeight: 300)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MurinookPalette.window)
        .onExitCommand(perform: dismiss)
    }
}

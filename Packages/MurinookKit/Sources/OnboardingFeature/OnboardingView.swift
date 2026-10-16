import MurinookDesignSystem
import MurinookUseCases
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome, history, shelf, paste
    var symbol: String {
        switch self { case .welcome: "square.on.square"; case .history: "clock.arrow.circlepath"; case .shelf: "tray.full.fill"; case .paste: "keyboard" }
    }
}

public struct OnboardingView: View {
    private let store: PreferencesStore
    private let actions: OnboardingActions
    @State private var step: OnboardingStep = .welcome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(store: PreferencesStore, actions: OnboardingActions) { self.store = store; self.actions = actions }

    public var body: some View {
        VStack(spacing: 0) {
            header
            progress
            HStack(alignment: .center, spacing: 30) {
                copyColumn.frame(maxWidth: .infinity, alignment: .leading)
                onboardingIllustration.frame(width: 225, height: 218).accessibilityHidden(true)
            }
            .padding(.horizontal, 34).padding(.vertical, 18).frame(maxHeight: .infinity)
            footer
        }
        .frame(minWidth: 690, minHeight: 520).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MurinookPalette.window)
        .animation(MurinookMotion.settle(reduceMotion: reduceMotion), value: step)
    }

    private var header: some View {
        HStack {
            MurinookWindowControls()
            HStack(spacing: 7) {
                MurinookBrandMark(size: 22)
                Text("onboarding.product", bundle: .module)
            }.font(.system(size: 11, weight: .semibold)).foregroundStyle(MurinookPalette.muted)
            Spacer()
            Button { actions.finish() } label: { Text("onboarding.skip", bundle: .module) }
                .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(MurinookPalette.muted)
        }
        .frame(height: 48).padding(.horizontal, 22)
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { item in
                Capsule().fill(item.rawValue <= step.rawValue ? MurinookPalette.accent : MurinookPalette.border).frame(height: 3)
            }
            Text("onboarding.step \(step.rawValue + 1)", bundle: .module).font(.system(size: 11, weight: .medium)).foregroundStyle(MurinookPalette.muted).fixedSize()
                .padding(.leading, 5)
        }
        .padding(.horizontal, 34).padding(.top, 11).accessibilityElement(children: .combine)
    }

    private var copyColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            onboardingText("title.\(step.rawValue)")
                .font(.system(size: 26, weight: .semibold, design: .rounded)).tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
            onboardingText("message.\(step.rawValue)")
                .font(.system(size: 12)).lineSpacing(2).foregroundStyle(MurinookPalette.muted)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<bulletCount, id: \.self) { index in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(MurinookPalette.accent)
                        onboardingText("bullet.\(step.rawValue).\(index)")
                    }.font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                }
            }.padding(.top, 14)
            if step == .history {
                Toggle(isOn: captureBinding) { Text("settings.capture", bundle: .module) }
                    .toggleStyle(.switch).font(.system(size: 11, weight: .medium)).padding(.top, 13)
            }
            if step == .paste { pastePermissionControls.padding(.top, 14) }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .id(step)
        .transition(.opacity.combined(with: .offset(x: reduceMotion ? 0 : 8)))
    }

    private var bulletCount: Int { step == .history ? 2 : 3 }

    private var pastePermissionControls: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label { Text("onboarding.permissionExplanation", bundle: .module) } icon: { Image(systemName: "hand.raised.fill") }
                .font(.system(size: 11)).foregroundStyle(MurinookPalette.muted).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button { actions.requestPastePermission() } label: { Text("onboarding.enablePaste", bundle: .module) }.buttonStyle(MurinookButtonStyle(variant: .primary))
                Button { actions.openAccessibilitySettings() } label: { Text("onboarding.permissionSettings", bundle: .module) }.buttonStyle(.link)
            }
        }
        .padding(11).frame(maxWidth: .infinity, alignment: .leading)
        .background(MurinookPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MurinookPalette.border, lineWidth: 1))
    }

    private var onboardingIllustration: some View { OnboardingIllustration(step: step.rawValue) }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { moveStep(by: -1) } label: { HStack(spacing: 6) { Image(systemName: "arrow.left"); Text("onboarding.back", bundle: .module) } }
                .buttonStyle(MurinookButtonStyle()).disabled(step == .welcome).opacity(step == .welcome ? 0.35 : 1)
            Spacer()
            if step == .paste {
                Button { actions.finish() } label: { HStack(spacing: 6) { Image(systemName: "checkmark"); Text("onboarding.finish", bundle: .module) } }.buttonStyle(MurinookButtonStyle(variant: .primary))
            } else {
                Button { moveStep(by: 1) } label: { HStack(spacing: 6) { Text("onboarding.continue", bundle: .module); Image(systemName: "arrow.right") } }
                    .buttonStyle(MurinookButtonStyle(variant: .primary)).keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 24).frame(height: 62)
        .overlay(alignment: .top) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
    }

    private var captureBinding: Binding<Bool> { Binding(get: { store.value.captureEnabled }, set: { value in store.update { $0.captureEnabled = value } }) }
    private func onboardingText(_ suffix: String) -> Text { Text(LocalizedStringKey("onboarding." + suffix), bundle: .module) }
    private func moveStep(by offset: Int) {
        guard let next = OnboardingStep(rawValue: step.rawValue + offset) else { return }
        step = next
    }
}

import MurinookDesignSystem
import MurinookUseCases
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome, clipboard, shelf, windows
}

public struct OnboardingView: View {
    private let store: PreferencesStore
    private let actions: OnboardingActions
    @State private var step: OnboardingStep = .welcome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(store: PreferencesStore, actions: OnboardingActions) {
        self.store = store
        self.actions = actions
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            progress
            ScrollView {
                HStack(alignment: .center, spacing: 28) {
                    OnboardingPage(step: step, store: store, actions: actions)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    OnboardingIllustration(step: step.rawValue)
                        .frame(width: 225, height: 218).accessibilityHidden(true)
                }
                .padding(.horizontal, 34).padding(.vertical, 24)
                .id(step)
                .transition(.opacity.combined(with: .offset(x: reduceMotion ? 0 : 8)))
            }
            footer
        }
        .frame(minWidth: 730, minHeight: 590)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Button(action: actions.finish) { Text("onboarding.skip", bundle: .module) }
                .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(MurinookPalette.muted)
        }.frame(height: 48).padding(.horizontal, 22)
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { item in
                Capsule().fill(item.rawValue <= step.rawValue ? MurinookPalette.accent : MurinookPalette.border).frame(height: 3)
            }
            Text("onboarding.step \(step.rawValue + 1)", bundle: .module)
                .font(.system(size: 11, weight: .medium)).foregroundStyle(MurinookPalette.muted).fixedSize().padding(.leading, 5)
        }.padding(.horizontal, 34).padding(.top, 11).accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { moveStep(by: -1) } label: {
                Label { Text("onboarding.back", bundle: .module) } icon: { Image(systemName: "arrow.left") }
            }.buttonStyle(MurinookButtonStyle()).disabled(step == .welcome)
            Spacer()
            Button {
                if step == .windows { actions.finish() } else { moveStep(by: 1) }
            } label: {
                HStack(spacing: 6) {
                    Text(step == .windows ? "onboarding.finish" : "onboarding.continue", bundle: .module)
                    Image(systemName: step == .windows ? "checkmark" : "arrow.right")
                }
            }.buttonStyle(MurinookButtonStyle(variant: .primary)).keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24).frame(height: 62)
        .overlay(alignment: .top) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
    }

    private func moveStep(by offset: Int) {
        guard let next = OnboardingStep(rawValue: step.rawValue + offset) else { return }
        step = next
    }
}

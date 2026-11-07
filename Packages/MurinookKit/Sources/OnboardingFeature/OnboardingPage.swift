import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct OnboardingPage: View {
    let step: OnboardingStep
    let store: PreferencesStore
    let actions: OnboardingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(LocalizedStringKey("onboarding.title." + String(step.rawValue)), bundle: .module)
                .font(.system(size: 26, weight: .semibold, design: .rounded)).tracking(-0.7)
                .accessibilityAddTraits(.isHeader)
            Text(LocalizedStringKey("onboarding.message." + String(step.rawValue)), bundle: .module)
                .font(.system(size: 12)).lineSpacing(2).foregroundStyle(MurinookPalette.muted)
            ForEach(0..<2, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(MurinookPalette.accent)
                    Text(LocalizedStringKey("onboarding.bullet." + String(step.rawValue) + "." + String(index)), bundle: .module)
                }.font(.system(size: 11))
            }
            if let keyPath = featureKeyPath {
                Toggle(isOn: Binding(get: { store.value[keyPath: keyPath] }, set: { enabled in
                    store.update { $0[keyPath: keyPath] = enabled }
                })) {
                    Text(LocalizedStringKey("onboarding.enabled." + String(step.rawValue)), bundle: .module)
                }.toggleStyle(.switch).font(.system(size: 12, weight: .medium))
                Text("onboarding.changeLater", bundle: .module)
                    .font(.system(size: 10)).foregroundStyle(MurinookPalette.muted)
            }
            if store.errorMessage != nil {
                MurinookErrorBanner(localizationKey: store.error?.localizationKey ?? "core.error.persistence")
            }
            if step == .clipboard {
                OnboardingPermissionCard(capability: .paste, actions: actions)
            } else if step == .windows {
                OnboardingPermissionCard(capability: .windows, actions: actions)
            }
        }
        .foregroundStyle(MurinookPalette.text)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var featureKeyPath: WritableKeyPath<AppPreferences, Bool>? {
        switch step {
        case .welcome: nil
        case .clipboard: \.clipboardEnabled
        case .shelf: \.shelfEnabled
        case .windows: \.windowManagementEnabled
        }
    }
}

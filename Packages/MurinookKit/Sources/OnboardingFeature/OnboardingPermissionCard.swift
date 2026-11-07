import AppKit
import MurinookDesignSystem
import SwiftUI

/// Each permission is checked independently: posting paste events and resizing
/// other apps' windows are separate capabilities even if Settings groups them.
struct OnboardingPermissionCard: View {
    enum Capability: String { case paste, windows }
    let capability: Capability
    let actions: OnboardingActions
    @State private var granted = false
    @State private var didCheck = false
    @State private var pollGeneration = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label {
                Text(LocalizedStringKey("onboarding.access." + capability.rawValue), bundle: .module)
            } icon: { Image(systemName: "hand.raised.fill") }
            .font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
            Text(granted ? "onboarding.access.granted" : (didCheck ? "onboarding.access.missing" : "onboarding.access.unknown"), bundle: .module)
                .font(.system(size: 11, weight: .medium))
                .accessibilityAddTraits(.updatesFrequently)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { permissionButtons }
                VStack(alignment: .leading, spacing: 8) { permissionButtons }
            }
            Button {
                actions.openAccessibilitySettings()
                pollGeneration += 1
            } label: { Text("onboarding.permissionSettings", bundle: .module) }
                .buttonStyle(.link).font(.system(size: 11))
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(MurinookPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MurinookPalette.border, lineWidth: 1))
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
        .task(id: pollGeneration) {
            guard pollGeneration > 0 else { return }
            for _ in 0..<30 {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard !Task.isCancelled else { return }
                refresh()
                if granted { return }
            }
        }
    }

    @ViewBuilder private var permissionButtons: some View {
        if !granted {
            Button {
                switch capability {
                case .paste: _ = actions.requestPostEventAccess()
                case .windows: _ = actions.requestWindowAccessibilityAccess()
                }
                refresh()
                pollGeneration += 1
            } label: { Text("onboarding.access.request", bundle: .module) }
                .buttonStyle(MurinookButtonStyle(variant: .primary))
        }
        Button(action: refresh) {
            Text("onboarding.checkPermission", bundle: .module)
        }.buttonStyle(.link)
    }

    private func refresh() {
        let previous = granted
        switch capability {
        case .paste: granted = actions.hasPostEventAccess()
        case .windows: granted = actions.hasWindowAccessibilityAccess()
        }
        didCheck = true
        if capability == .paste && granted && !previous { actions.permissionGranted() }
    }
}

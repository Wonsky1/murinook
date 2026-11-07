import AppKit
import MurinookDesignSystem
import SwiftUI

/// Keeps permission UI current when hosted in either a SwiftUI scene or an AppKit window.
struct PermissionSettingsControl: View {
    let grantedKey: String
    let missingKey: String
    let check: () -> Bool
    let request: () -> Bool
    let openSettings: () -> Void
    @State private var granted = false
    @State private var pollGeneration = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(granted ? MurinookPalette.accent : MurinookPalette.warm).frame(width: 7, height: 7)
                Text(LocalizedStringKey(granted ? grantedKey : missingKey), bundle: .module)
                    .font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                if !granted {
                    Button {
                        _ = request()
                        refresh()
                        pollGeneration += 1
                    } label: { Text("settings.permission.request", bundle: .module) }
                        .buttonStyle(.borderedProminent)
                }
                Button(action: refresh) { Text("settings.permission.check", bundle: .module) }.buttonStyle(.bordered)
                Button {
                    openSettings()
                    pollGeneration += 1
                } label: { Text("settings.permission.openSettings", bundle: .module) }.buttonStyle(.link)
            }
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
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

    private func refresh() { granted = check() }
}

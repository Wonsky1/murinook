import MurinookUseCases
import MurinookDomain
import MurinookDesignSystem
import MurinookMacIntegration
import AppKit
import SwiftUI

struct MenuBarContent: View {
    let controller: ApplicationController
    @Environment(\.dismiss) private var dismiss
    private var preferences: AppPreferences { controller.services.preferences.value }
    private var locale: Locale { preferences.languageCode.map(Locale.init(identifier:)) ?? .current }
    private func label(_ key: String) -> String { AppStrings.text(key, locale: locale) }

    var body: some View {
        FeatureEnvironment(preferences: controller.services.preferences) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    MurinookBrandMark(size: 29)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Murinook").font(.system(size: 13, weight: .semibold))
                        Text(label(preferences.captureEnabled ? "History is being captured" : "Capture is paused"))
                            .font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
                    }
                    Spacer()
                    Circle().fill(preferences.captureEnabled ? MurinookPalette.accent : MurinookPalette.warm)
                        .frame(width: 6, height: 6).accessibilityHidden(true)
                }.padding(16)
                if let clip = controller.services.history.clips.max(by: { $0.lastCopiedAt < $1.lastCopiedAt }) {
                    latestCopy(clip)
                }
                separator
                if let problem = controller.startupProblem {
                    Text(problem).font(.caption).padding(12)
                    row("Try again", symbol: "arrow.clockwise") { Task { await controller.start() } }
                }
                VStack(spacing: 0) {
                    row("Quick access", symbol: "magnifyingglass", shortcut: .quickAccess, action: controller.windows.showQuick)
                    row("Library", symbol: "square.grid.2x2", shortcut: .library, action: controller.windows.showLibrary)
                    row("Show shelf", symbol: "tray", count: controller.services.shelf.items.count, action: controller.windows.shelf.show)
                    row("Paste queue", symbol: "rectangle.stack", count: controller.services.queue.entries.count, action: controller.windows.showQueue)
                    row("Paste next", symbol: "arrow.right", shortcut: .pasteNext) { controller.perform(.pasteNext) }
                        .disabled(controller.services.queue.next == nil)
                    separator.padding(.vertical, 5)
                    row(preferences.captureEnabled ? "Pause capture" : "Resume capture", symbol: preferences.captureEnabled ? "pause" : "play") {
                        controller.services.preferences.update { $0.captureEnabled.toggle() }
                    }
                    row("Settings", symbol: "gearshape", action: controller.windows.showSettings)
                }.disabled(!controller.isReady)
                separator.padding(.vertical, 5)
                if case .available(let release) = controller.updates.store.state {
                    HStack(spacing: 8) {
                        Circle().fill(MurinookPalette.accent).frame(width: 6, height: 6)
                        Text(label("Update available") + " · " + release.version.description)
                            .font(.system(size: 11, weight: .semibold))
                    }.foregroundStyle(MurinookPalette.accent).padding(.horizontal, 15).padding(.top, 6)
                }
                row("Check for updates", symbol: "arrow.triangle.2.circlepath") {
                    controller.windows.showUpdateSettings()
                    controller.updates.checkManually()
                }
                Text(controller.updates.versionLabel)
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(MurinookPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.bottom, 3)
                row("Quit Murinook", symbol: "power") { NSApp.terminate(nil) }
            }.padding(.bottom, 7).frame(width: 282)
                .foregroundStyle(MurinookPalette.text).background(MurinookPalette.surface)
        }
    }

    private func latestCopy(_ clip: Clip) -> some View {
        Button {
            dismiss()
            controller.windows.showQuick()
        } label: {
            HStack(spacing: 10) {
                MurinookContentIcon(data: clip.iconData, kindIdentifier: clip.kind.rawValue,
                                    symbol: clip.kind.symbolName, size: 31)
                VStack(alignment: .leading, spacing: 4) {
                    MurinookContentTitle(clip.title, kindIdentifier: clip.kind.rawValue)
                        .font(.system(size: 11, weight: .medium)).lineLimit(1)
                    Text(clip.source.name + " · " + clip.lastCopiedAt.formatted(.dateTime.hour().minute().locale(locale)))
                        .font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(11).background(MurinookPalette.page, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).padding(.horizontal, 10).padding(.bottom, 9)
    }

    private var separator: some View { Rectangle().fill(MurinookPalette.border).frame(height: 1).padding(.horizontal, 10) }

    private func row(_ key: String, symbol: String, shortcut: ShortcutAction? = nil,
                     count: Int? = nil, action: @escaping () -> Void) -> some View {
        Button {
            dismiss()
            action()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol).font(.system(size: 13)).frame(width: 18).accessibilityHidden(true)
                Text(label(key)).font(.system(size: 12))
                Spacer(minLength: 4)
                if let shortcut, let combination = preferences.shortcuts[shortcut] {
                    Text(ShortcutDescriptionFormatter.string(for: combination))
                        .font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
                }
                if let count { Text(count.formatted(.number.locale(locale))).font(.system(size: 11)).foregroundStyle(MurinookPalette.muted) }
            }.padding(.horizontal, 13).frame(minHeight: 33).contentShape(Rectangle())
        }.buttonStyle(MenuRowStyle())
    }
}

private struct MenuRowStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        MenuRowLabel(configuration: configuration).opacity(enabled ? 1 : 0.4)
    }
    private struct MenuRowLabel: View {
        let configuration: Configuration
        @State private var hovered = false
        var body: some View {
            configuration.label.background(hovered || configuration.isPressed ? MurinookPalette.accentSoft : .clear,
                in: RoundedRectangle(cornerRadius: 5)).padding(.horizontal, 5).onHover { hovered = $0 }
        }
    }
}

import AppKit
import ApplicationServices
import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

public struct SettingsView: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let store: PreferencesStore
    private let actions: SettingsActions
    private let updates: UpdateStore?
    private let currentVersion: String
    @State private var navigation: SettingsNavigation
    @State private var confirmsHistoryClear = false

    public init(store: PreferencesStore, actions: SettingsActions, navigation: SettingsNavigation? = nil,
                updates: UpdateStore? = nil, currentVersion: String = "") {
        self.store = store
        self.actions = actions
        self.updates = updates
        self.currentVersion = currentVersion
        self._navigation = State(initialValue: navigation ?? SettingsNavigation())
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(MurinookPalette.border).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(LocalizedStringKey("settings.section." + navigation.selection.rawValue), bundle: .module)
                        .font(.system(size: 25, weight: .semibold)).tracking(-0.7).padding(.top, 5)
                    Text(LocalizedStringKey("settings.lead." + navigation.selection.rawValue), bundle: .module)
                        .font(.system(size: 12)).foregroundStyle(MurinookPalette.muted).fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4).padding(.bottom, 20)
                    sectionContent
                    if store.errorMessage != nil {
                        MurinookErrorBanner(localizationKey: store.error?.localizationKey ?? "core.error.persistence").padding(.top, 15)
                    }
                }
                .frame(maxWidth: 630, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 34).padding(.vertical, 27)
            }
            .background(MurinookPalette.window)
        }
        .frame(minWidth: 760, minHeight: 550)
        .background(MurinookPalette.window)
        .animation(MurinookMotion.settle(reduceMotion: reduceMotion), value: navigation.selection)
        .confirmationDialog(Text("settings.clearHistory.confirmTitle", bundle: .module), isPresented: $confirmsHistoryClear, titleVisibility: .visible) {
            Button(role: .destructive) { actions.clearUnpinnedHistory() } label: { Text("settings.clearHistory.confirm", bundle: .module) }
            Button(role: .cancel) {} label: { Text("settings.cancel", bundle: .module) }
        } message: {
            Text(String.localizedStringWithFormat(String(localized: "settings.clearHistory.confirmMessageCount", bundle: .module), actions.unpinnedHistoryCount()))
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            MurinookWindowControls().padding(.leading, 6).padding(.bottom, 20)
            ForEach(SettingsSection.allCases) { section in
                Button { navigation.selection = section } label: {
                    HStack(spacing: 9) {
                        Image(systemName: section.symbol).frame(width: 16)
                        Text(LocalizedStringKey("settings.section." + section.rawValue), bundle: .module)
                    }
                        .font(.system(size: 12, weight: navigation.selection == section ? .semibold : .regular))
                        .foregroundStyle(navigation.selection == section ? MurinookPalette.accent : MurinookPalette.text.opacity(0.82))
                        .frame(maxWidth: .infinity, minHeight: 35, alignment: .leading).padding(.horizontal, 10)
                        .background(navigation.selection == section ? MurinookPalette.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityAddTraits(navigation.selection == section ? .isSelected : [])
            }
            Spacer(minLength: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text("settings.title", bundle: .module).font(.system(size: 11, weight: .semibold))
                Text("settings.sidebarCaption", bundle: .module).font(.system(size: 11)).foregroundStyle(MurinookPalette.soft)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.top, 13)
            .overlay(alignment: .top) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
        }
        .padding(.horizontal, 12).padding(.top, 23).padding(.bottom, 14).frame(width: 190)
        .background(MurinookPalette.sidebar)
    }

    @ViewBuilder private var sectionContent: some View {
        Group {
            switch navigation.selection {
            case .general: GeneralSettingsSection(store: store, actions: actions, languageName: languageName)
            case .history: HistorySettingsSection(store: store, clear: { confirmsHistoryClear = true }, count: actions.unpinnedHistoryCount)
            case .privacy: PrivacySettingsSection(store: store, actions: actions)
            case .shortcuts: ShortcutsSettingsSection(store: store, actions: actions)
            case .shelf: ShelfSettingsSection(store: store)
            case .updates: UpdateSettingsSection(preferences: store, updates: updates, currentVersion: currentVersion, actions: actions)
            }
        }
        .id(navigation.selection)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private func languageName(_ code: String) -> String { locale.localizedString(forLanguageCode: code)?.capitalized ?? code }
}

import AppKit
import ApplicationServices
import MurinookDesignSystem
import MurinookDomain
import MurinookUseCases
import SwiftUI

struct SettingsGroup<Content: View>: View {
    let key: String; let detail: String; let icon: String; @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) { Image(systemName: icon).font(.system(size: 12)).foregroundStyle(MurinookPalette.accent).frame(width: 30, height: 30).background(MurinookPalette.accentSoft, in: RoundedRectangle(cornerRadius: 9)); VStack(alignment: .leading, spacing: 3) { Text(LocalizedStringKey(key), bundle: .module).font(.system(size: 12, weight: .semibold)); Text(LocalizedStringKey(detail), bundle: .module).font(.system(size: 11)).foregroundStyle(MurinookPalette.muted).fixedSize(horizontal: false, vertical: true) } }
            content().padding(.leading, 40)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14).overlay(alignment: .top) { Rectangle().fill(MurinookPalette.border).frame(height: 1) }
    }
}

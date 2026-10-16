import AppKit
import MurinookDesignSystem
import SwiftUI

/// Observe startup inside the hosted view so the menu replaces its initial content.
struct MenuBarRootView: View {
    @ObservedObject var delegate: AppDelegate

    var body: some View {
        if let controller = delegate.controller {
            MenuBarContent(controller: controller)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if let error = delegate.startupError {
                    Text(AppStrings.text("Could not open Murinook storage"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(error).font(.system(size: 11)).foregroundStyle(MurinookPalette.muted)
                        .textSelection(.enabled)
                } else {
                    HStack(spacing: 9) {
                        ProgressView().controlSize(.small)
                        Text(AppStrings.text("Opening Murinook…")).font(.system(size: 12))
                    }
                }
                Divider()
                Button { NSApp.terminate(nil) } label: {
                    Label(AppStrings.text("Quit Murinook"), systemImage: "power")
                }.buttonStyle(.plain).font(.system(size: 12))
            }
            .padding(16).frame(width: 282, alignment: .leading)
            .foregroundStyle(MurinookPalette.text).background(MurinookPalette.surface)
        }
    }
}

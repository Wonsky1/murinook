//
//  MurinookApp.swift
//  Murinook
//
//  Created by Vlad Pidborskyi on 11.10.2026.
//

import MurinookDomain
import MurinookUseCases
import AppKit
import SwiftUI

@main
struct MurinookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private var locale: Locale {
        delegate.controller?.services.preferences.value.languageCode.map(Locale.init(identifier:)) ?? .current
    }
    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView(delegate: delegate)
        } label: {
            MenuBarLabel(delegate: delegate)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandMenu(AppStrings.text("Navigate", locale: locale)) {
                Button(AppStrings.text("Quick access", locale: locale)) { delegate.controller?.windows.showQuick() }
                Button(AppStrings.text("Library", locale: locale)) { delegate.controller?.windows.showLibrary() }
                Button(AppStrings.text("Show shelf", locale: locale)) { delegate.controller?.windows.shelf.show() }
                Button(AppStrings.text("Paste queue", locale: locale)) { delegate.controller?.windows.showQueue() }
            }
            CommandGroup(replacing: .appSettings) {
                Button(AppStrings.text("Settings", locale: locale) + "…") { delegate.controller?.windows.showSettings() }.keyboardShortcut(",")
            }
            CommandGroup(replacing: .newItem) {
                Button(AppStrings.text("Close window", locale: locale)) { NSApp.keyWindow?.performClose(nil) }.keyboardShortcut("w")
            }
        }
    }
}

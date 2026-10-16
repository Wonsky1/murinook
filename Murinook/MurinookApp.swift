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
    private var updateAvailable: Bool {
        if case .available = delegate.controller?.updates.store.state { return true }
        return false
    }
    var body: some Scene {
        MenuBarExtra {
            if let controller = delegate.controller {
                MenuBarContent(controller: controller)
            } else if let error = delegate.startupError {
                Text("Could not open Murinook storage")
                Text(error)
                Button("Quit Murinook") { NSApp.terminate(nil) }
            } else { Text("Opening Murinook…") }
        } label: {
            Image(nsImage: MenuBarSymbol.image)
                .overlay(alignment: .topTrailing) {
                    if updateAvailable { Circle().fill(.primary).frame(width: 4, height: 4) }
                }
                .accessibilityLabel(updateAvailable ? AppStrings.text("Murinook — update available", locale: locale) : "Murinook")
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

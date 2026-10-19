import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var controller: ApplicationController?
    @Published private(set) var startupError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "wonsky.Murinook"
            try SandboxDataMigration.migrate(bundleIdentifier: bundleIdentifier)
            let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true).appending(path: "Murinook", directoryHint: .isDirectory)
            let controller = try ApplicationController(directory: directory)
            self.controller = controller
            Task {
                await controller.start()
            }
        } catch { startupError = error.localizedDescription }
    }

    func applicationWillTerminate(_ notification: Notification) { controller?.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let controller, controller.isReady { controller.windows.reopen() }
        return false
    }
}

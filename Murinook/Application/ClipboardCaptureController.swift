import MurinookUseCases
import Foundation
import MurinookDomain
import MurinookMacIntegration

final class ClipboardCaptureController {
    private let services: ApplicationServices
    private var task: Task<Void, Never>?
    private var retentionTimer: Timer?

    init(services: ApplicationServices) { self.services = services }

    func start() {
        let stream = services.monitor.start()
        task = Task {
            for await snapshot in stream {
                guard !Task.isCancelled else { break }
                let source = SourceApplication(name: snapshot.sourceApplicationName ?? "",
                    bundleIdentifier: snapshot.sourceBundleIdentifier)
                for content in snapshot.toContents() {
                    await services.contentAccess.withAccess {
                        let decorated = await services.visuals.addingVisuals(to: content)
                        await services.history.capture(decorated, source: source)
                    }
                }
            }
        }
        retentionTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.services.history.enforceRetention(now: .now) }
        }
    }

    func stop() {
        task?.cancel(); task = nil
        services.monitor.stop()
        retentionTimer?.invalidate(); retentionTimer = nil
    }
}

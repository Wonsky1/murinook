import Foundation

@MainActor
protocol ClipboardPolling: AnyObject {
    func start(interval: TimeInterval, tick: @escaping @MainActor @Sendable () -> Void)
    func stop()
}

@MainActor
final class RunLoopClipboardPolling: ClipboardPolling {
    private var timer: Timer?

    func start(interval: TimeInterval, tick: @escaping @MainActor @Sendable () -> Void) {
        stop()
        let timer = Timer(timeInterval: max(0.05, interval), repeats: true) { _ in
            Task { @MainActor in tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

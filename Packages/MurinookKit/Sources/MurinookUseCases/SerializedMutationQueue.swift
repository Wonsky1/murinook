import Foundation

@MainActor final class SerializedMutationQueue {
    private let accessGate: ContentAccessGate?
    private var tail: Task<Void, Never> = Task {}

    init(accessGate: ContentAccessGate? = nil) {
        self.accessGate = accessGate
    }

    func run(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = tail
        let current = Task {
            await previous.value
            if let accessGate {
                await accessGate.withAccess(operation)
            } else {
                await operation()
            }
        }
        tail = current
        await current.value
    }
}

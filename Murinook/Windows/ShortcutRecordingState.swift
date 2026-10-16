import MurinookDomain
import Observation

@MainActor @Observable
final class ShortcutRecordingState {
    var candidate: KeyCombination?
    var errorMessage: String?
}

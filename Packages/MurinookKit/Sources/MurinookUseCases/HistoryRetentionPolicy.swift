import Foundation
import MurinookDomain

enum HistoryRetentionPolicy {
    static func apply(_ clips: [Clip], preferences: AppPreferences, now: Date) -> [Clip] {
        let threshold = now.addingTimeInterval(-Double(preferences.retentionDays) * 86_400)
        let eligible = clips.filter { clip in
            clip.isPinned || preferences.retentionDays == 0 || clip.lastCopiedAt >= threshold
        }
        var kept: [Clip] = []
        var ordinaryItemCount = 0

        for clip in eligible.sorted(by: { $0.lastCopiedAt > $1.lastCopiedAt }) {
            guard !clip.isPinned else {
                kept.append(clip)
                continue
            }
            if preferences.maxHistoryItems > 0, ordinaryItemCount >= preferences.maxHistoryItems { continue }
            kept.append(clip)
            ordinaryItemCount += 1
        }
        return kept
    }
}

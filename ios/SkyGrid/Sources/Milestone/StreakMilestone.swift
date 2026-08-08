import Foundation

/// A streak length worth stopping the app for.
///
/// Part of the deliberate persona change recorded in `VISION.md` §6 (revised
/// 2026-08-08): the morning ritual stays quiet, but the things other people see —
/// the share card, the streak, and this moment — are loud. A milestone is rare by
/// construction, so it never becomes the ambient "level up" noise §6 still bans.
struct StreakMilestone: Equatable, Sendable, Identifiable {
    let streak: Int

    var id: Int { streak }

    /// Sparse on purpose: frequent enough early that a new user gets a reason to
    /// share before they have a grid worth sharing, then rare enough that reaching
    /// one still means something.
    static let thresholds: [Int] = [1, 7, 14, 30, 50, 100, 200, 365]

    /// Requires an **exact** hit, not a crossing.
    ///
    /// A "crossed the threshold" rule would celebrate 7 on a morning every other
    /// surface calls 8, and would back-fill every skipped threshold after a reinstall
    /// surfaced 130 days of history at once. `lastCelebrated` is a monotonic
    /// high-water mark, so each threshold fires at most once per install.
    static func reached(streak: Int, lastCelebrated: Int) -> StreakMilestone? {
        guard streak > lastCelebrated, thresholds.contains(streak) else { return nil }
        return StreakMilestone(streak: streak)
    }

    var isFirstMorning: Bool { streak == 1 }

    var title: String {
        isFirstMorning ? "Day one" : "\(streak) days"
    }

    var headline: String {
        switch streak {
        case 1: return "Your first sky."
        case 7: return "A full week of mornings."
        case 14: return "Two weeks. It's a habit now."
        case 30: return "Thirty mornings in a row."
        case 50: return "Fifty skies, one at a time."
        case 100: return "One hundred mornings."
        case 200: return "Two hundred. Almost a year of skies."
        case 365: return "A whole year. Every single morning."
        default: return "\(streak) mornings in a row."
        }
    }
}

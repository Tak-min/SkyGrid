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

    // Routed through `L10n.string(_:)` (explicit key lookup) rather than plain string
    // literals: these values are stored `String` properties consumed elsewhere as
    // `Text(milestone.title)`, not string literals inside a `Text(...)` call site, so
    // SwiftUI's automatic String-Catalog key matching never applies to them (see
    // `dev-notes/localization-en-ja-stage2_*.md`). Resolving the correct language here,
    // at the source, means every consumer gets already-localized text for free.
    var title: String {
        isFirstMorning
            ? L10n.string("milestone.title.dayOne")
            : String(format: L10n.string("milestone.title.streakDays"), streak)
    }

    var headline: String {
        switch streak {
        case 1: return L10n.string("milestone.headline.streak1")
        case 7: return L10n.string("milestone.headline.streak7")
        case 14: return L10n.string("milestone.headline.streak14")
        case 30: return L10n.string("milestone.headline.streak30")
        case 50: return L10n.string("milestone.headline.streak50")
        case 100: return L10n.string("milestone.headline.streak100")
        case 200: return L10n.string("milestone.headline.streak200")
        case 365: return L10n.string("milestone.headline.streak365")
        default: return String(format: L10n.string("milestone.headline.default"), streak)
        }
    }
}

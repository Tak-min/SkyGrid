import Foundation

struct StreakSummary: Equatable, Sendable {
    let currentStreak: Int
    let hasPostedToday: Bool
}

/// Ported from Unhook's `StreakCalculator` (`~/Desktop/Unhook/ios/Unhook/Sources/DailyLoop/StreakCalculator.swift`)
/// and extended with `exemptDays` (blueprint §3.3): a day that's exempt neither
/// requires a post nor breaks the chain, but also never increments the count itself
/// — it's a "pass-through" day (timezone-change skip, or a used rest day).
///
/// Grace behavior (kept from Unhook): if today hasn't been posted yet, the streak is
/// still "alive" as of yesterday's count — the day isn't over, so we don't punish the
/// user before they've had their morning.
enum StreakCalculator {
    static func summarize(
        postedDays: [LocalDate],
        today: LocalDate,
        exemptDays: Set<LocalDate> = []
    ) -> StreakSummary {
        let posted = Set(postedDays)
        let hasPostedToday = posted.contains(today)
        let yesterday = today.adding(days: -1)

        let anchor: LocalDate?
        if hasPostedToday {
            anchor = today
        } else if posted.contains(yesterday) || exemptDays.contains(yesterday) {
            anchor = yesterday
        } else {
            anchor = nil
        }

        guard let streakAnchor = anchor else {
            return StreakSummary(currentStreak: 0, hasPostedToday: false)
        }

        var streak = 0
        var cursor = streakAnchor
        while posted.contains(cursor) || exemptDays.contains(cursor) {
            if posted.contains(cursor) { streak += 1 }
            cursor = cursor.adding(days: -1)
        }
        return StreakSummary(currentStreak: streak, hasPostedToday: hasPostedToday)
    }
}

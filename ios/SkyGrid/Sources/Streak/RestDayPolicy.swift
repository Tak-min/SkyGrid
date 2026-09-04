import Foundation

/// VISION.md §3, pain point #3: even on the free tier, one missed morning per week
/// doesn't have to break the chain — this is the policy `StreakCalculator`'s
/// `exemptDays` gets fed from (in addition to timezone-change days).
///
/// **Redesigned 2026-09-04 (Opus architecture consult, see
/// `.loop/codex-handoff-log.md` "Item 2").** The previous shape —
/// `hasRestDayAvailable(usedRestDaysThisWeek:isPro:)` — was never actually wired to
/// anything (`TodayViewModel` always passed `exemptDays: []`) and had two real
/// defects, not just a monetization-taste one, that this redesign fixes by
/// construction:
/// 1. `isPro` unlimited rest days made a Pro streak unfalsifiable, and fed a
///    *current* entitlement into a *historical* calculation — a lapsed
///    subscription would retroactively un-exempt past days and collapse the
///    streak it had itself granted.
/// 2. A persisted `usedRestDaysThisWeek` counter would need its own Firestore
///    field and rules change and would be a forgeable client counter.
///
/// The fix removes both problems at once: `freeRestDaysPerWeek` is a single
/// entitlement-independent constant (same for every account, no Pro
/// differentiation), and "used this week" is never persisted — it's recomputed
/// on every call as a pure function of `postedDays`, the same way
/// `StreakCalculator`'s own already-accepted client-side streak is. Backfilling a
/// missed day (taking a makeup photo later) remains explicitly out of scope — see
/// the dev-note: it would make every Grid cell an unfalsifiable claim. This policy
/// only ever *forgives* a gap; it never lets a day be posted for after the fact.
enum RestDayPolicy {
    static let freeRestDaysPerWeek = 1

    /// Days that should be treated as exempt (neither require a post nor break the
    /// chain, but never increment the streak either — see `StreakCalculator`) for
    /// fixed Monday-Sunday calendar-week blocks, never a sliding 7-day window: a
    /// sliding window would let someone "bank" a rest day by choosing which day to
    /// check from, since the same missed day could fall inside more than one
    /// window. Within each block, at most `freeRestDaysPerWeek` missed days are
    /// exempted, chosen deterministically (earliest-first) so the result never
    /// depends on call order or is randomized.
    static func exemptDays(postedDays: [LocalDate], today: LocalDate) -> Set<LocalDate> {
        guard let earliest = postedDays.min() else { return [] }
        let posted = Set(postedDays)

        var exempt: Set<LocalDate> = []
        var blockStart = weekBlockStart(for: earliest)
        let lastBlockStart = weekBlockStart(for: today)
        while blockStart <= lastBlockStart {
            // `>= earliest` matters even within `earliest`'s own week block: a day
            // before the caller's earliest known post isn't a "missed" day, it's a
            // day this function has no data for (the query window doesn't reach
            // that far back, or the account didn't exist yet) — never grant a rest
            // day for a gap that was never actually observed.
            let missedThisBlock = (0..<7)
                .map { blockStart.adding(days: $0) }
                .filter { $0 >= earliest && $0 <= today && !posted.contains($0) }
            exempt.formUnion(missedThisBlock.prefix(freeRestDaysPerWeek))
            blockStart = blockStart.adding(days: 7)
        }
        return exempt
    }

    /// The Monday that starts `date`'s fixed calendar-week block.
    private static func weekBlockStart(for date: LocalDate) -> LocalDate {
        // `weekday`: 1=Sun...7=Sat. Days back to that block's Monday: Sun->6,
        // Mon->0, Tue->1, ..., Sat->5.
        let daysSinceMonday = (date.weekday + 5) % 7
        return date.adding(days: -daysSinceMonday)
    }
}

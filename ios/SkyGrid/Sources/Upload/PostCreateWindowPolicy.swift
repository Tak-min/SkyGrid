import Foundation

/// Mirrors the past-side bound of `firestore.rules`' `isRecentLocalDate(localDate)`
/// (added 2026-09-04, see `.loop/codex-handoff-log.md` "Item 2" and its security
/// review) — but deliberately conservative, not an exact reimplementation.
///
/// The server compares `timestamp.date(localDate)` (midnight UTC of that calendar
/// day) against `request.time` (the real instant of the write) with a nominal
/// "±2 days" duration. Because that comparison is against a real instant rather
/// than a calendar-day difference, the *practical* past bound is much tighter than
/// 2 calendar days: a `localDate` 2 days behind today is already outside the
/// server's accepted window for nearly its entire day (confirmed empirically
/// against the Firestore emulator, see `ios/rules-tests/test.js` — "blocks
/// creating a post for a date years in the past" and hand-tested day-offset
/// cases). This policy exists so the client can stop offering a "Retry now" that
/// can never succeed (the bug this type fixes — see the security review's HIGH-2)
/// without needing to reproduce the server's exact instant-level arithmetic:
/// `maxPastDays = 1` only ever flags a row once even the more lenient
/// calendar-day reading of the bound would already reject it, so this can never
/// block a retry the server would actually still accept — only ever the reverse
/// (a very small window right at a day boundary where the server might already be
/// rejecting a row this policy hasn't flagged yet, which just means one wasted,
/// harmless retry attempt, not a false "you can't retry this").
///
/// Deliberately does not mirror the future-side bound: that leniency is a known,
/// accepted gap (see the security review's HIGH-1) that this loop iteration was
/// explicitly told not to change.
enum PostCreateWindowPolicy {
    static let maxPastDays = 1

    /// Whether a post for `localDate` can no longer be created against
    /// `firestore.rules`' current window as of `today`.
    static func isTooOldToRetry(localDate: LocalDate, today: LocalDate) -> Bool {
        localDate.daysUntil(today) > maxPastDays
    }
}

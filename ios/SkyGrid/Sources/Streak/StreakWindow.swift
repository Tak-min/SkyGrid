import Foundation

/// How many days of posts the Today screen must observe to be able to state a
/// correct streak.
///
/// The streak is computed **client-side and display-only**. It is deliberately not
/// read from `UserProfile.streakCurrent`, because nothing writes that field:
/// `firestore.rules` restricts `/users/{uid}` updates to
/// `['displayName','timezone','wakeGoalMinutes']` with the comment "streak values
/// are server-owned", and no Cloud Function computes them (`functions/src/index.ts`
/// exports only `deleteAccount`, `imageDownloadURL`, `revenueCatWebhook`). The field
/// is therefore permanently `0` in production and must never be displayed.
///
/// Cost note: this widens Today's existing post listener from 7 documents to
/// `observedDays`. It does **not** add a listener — the same stream feeds both the
/// week rhythm and the streak. For scale context, `GridArchiveView` already attaches
/// a 365-document year listener every time the Grid tab appears, so this is strictly
/// cheaper than a pattern the app already accepts.
enum StreakWindow {
    /// Long enough that the overwhelming majority of streaks are computable from one
    /// snapshot, short enough to stay well under the archive listener's 365.
    static let observedDays = 120

    /// Re-anchors the window before a growing streak can reach its edge, so a long
    /// streak is never silently truncated to the window length. Called with the
    /// currently computed streak; the extra 30 days is headroom so this doesn't have
    /// to re-widen every single morning once a user passes the threshold.
    static func widened(forStreak streak: Int) -> Int {
        max(observedDays, streak + 30)
    }

    /// True when a computed streak is close enough to the window edge that the next
    /// few days could exceed it.
    static func needsWidening(streak: Int, windowDays: Int) -> Bool {
        streak >= windowDays - 7
    }
}

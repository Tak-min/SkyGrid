import Foundation

/// The two entry points where the Live Activity and follow-up notification must
/// move together — one façade so a future call site can't remember one and
/// forget the other.
enum MorningRitualCoordinator {
    /// Call once a post is confirmed committed (Firestore + local outbox both
    /// written). Ends today's Live Activity and cancels today's follow-up in one
    /// place.
    static func captureCompleted(localDate: LocalDate) async {
        LocalDefaults.lastCapturedLocalDateID = localDate.docID
        await MorningRitualActivity.end(status: .captured)
        MorningFollowUpScheduler.cancel(for: localDate)
    }

    /// Call from every relevant foreground lifecycle hook (appear, scenePhase
    /// becoming active, destination change). This is the only start path on
    /// iOS 17–25, and on every OS version it is the safety net that clears a
    /// stale or yesterday's leftover card.
    static func reconcile(today: LocalDate, hasPostToday: Bool, now: Date, timeZone: TimeZone) async {
        let decision = MorningRitualPolicy.decide(
            now: now,
            timeZone: timeZone,
            wakeGoalMinutes: LocalDefaults.wakeGoalMinutes,
            isAlarmEnabled: LocalDefaults.morningAlarmEnabled,
            hasPostToday: hasPostToday,
            runningActivityLocalDateID: MorningRitualActivity.runningLocalDateID
        )
        switch decision {
        case .start(let localDateID, let wokeAt):
            MorningRitualActivity.start(localDateID: localDateID, wokeAt: wokeAt)
        case .end:
            await MorningRitualActivity.end(status: .captured)
        case .leaveAlone:
            break
        }
    }
}

import Foundation

/// The two entry points where the Live Activity and morning-notification cleanup
/// must move together — one façade so a future call site can't remember one and
/// forget the other.
@MainActor
enum MorningRitualCoordinator {
    /// Call once a post is confirmed committed (Firestore + local outbox both
    /// written). Ends today's Live Activity and cancels today's follow-up in one
    /// place, including every one-shot re-alarm.
    static func captureCompleted(localDate: LocalDate) async {
        LocalDefaults.lastCapturedLocalDateID = localDate.docID
        // A capture wins over an alarm/notification tap that happened moments
        // earlier. Leaving this flag set could reopen the camera after the post
        // has already ended the ritual.
        LocalDefaults.openCameraAfterMorningAlarm = false
        await MorningRitualActivity.end(status: .captured)
        MorningFollowUpScheduler.cancel(for: localDate)
        await MorningAlarmScheduler.cancelAllRealarmNotifications()
        LocalDefaults.morningRealarmAttemptCount = 0
        LocalDefaults.morningRealarmWakeDayID = nil
    }

    /// Call from every relevant foreground lifecycle hook (appear, scenePhase
    /// becoming active, destination change). This is the only start path on
    /// iOS 17–25, and on every OS version it is the safety net that clears a
    /// stale or yesterday's leftover card.
    static func reconcile(today: LocalDate, hasPostToday: Bool, now: Date, timeZone: TimeZone) async {
        // The server observer can briefly yield `nil` immediately after a local
        // create. The durable local confirmation is sufficient to end the
        // Activity; never let that read race recreate the Dynamic Island card.
        let effectiveHasPostToday = MorningRitualPolicy.effectiveHasPostToday(
            hasPostToday: hasPostToday,
            lastCapturedLocalDateID: LocalDefaults.lastCapturedLocalDateID,
            today: today
        )
        let decision = MorningRitualPolicy.decide(
            now: now,
            timeZone: timeZone,
            wakeGoalMinutes: LocalDefaults.wakeGoalMinutes,
            isAlarmEnabled: LocalDefaults.morningAlarmEnabled,
            hasPostToday: effectiveHasPostToday,
            runningActivityLocalDateID: MorningRitualActivity.runningLocalDateID
        )
        switch decision {
        case .start(let localDateID, let wokeAt):
            MorningRitualActivity.start(localDateID: localDateID, wokeAt: wokeAt)
        case .replace(let localDateID, let wokeAt):
            await MorningRitualActivity.end(status: .ended)
            MorningRitualActivity.start(localDateID: localDateID, wokeAt: wokeAt)
        case .end:
            await MorningRitualActivity.end(status: .ended)
        case .leaveAlone:
            break
        }
    }
}

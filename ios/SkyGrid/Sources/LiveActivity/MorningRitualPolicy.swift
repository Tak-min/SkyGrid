import Foundation

/// Every "should the morning-ritual nudge be visible right now" decision lives
/// here, as a pure function — `MorningRitualActivity`/`MorningRitualCoordinator`
/// are thin, untested shims around it, matching the rest of this codebase's
/// policy/shim split (see `FirstUnlockPaywallPolicy`, `RestDayPolicy`).
enum MorningRitualPolicy {
    /// How long after the wake time the nudge stays relevant. Past this, a
    /// lingering Lock Screen card would be noise, not a nudge.
    static let morningWindowMinutes = Int(MorningRitualAttributes.captureWindow / 60)
    /// The single soft follow-up notification, per the chosen design.
    static let followUpDelayMinutes = 20
    /// How many days of one-shot follow-ups stay armed at a time.
    static let followUpWindowDays = 7

    enum Decision: Equatable {
        case start(localDateID: String, wokeAt: Date)
        case replace(localDateID: String, wokeAt: Date)
        case end
        case leaveAlone
    }

    /// A committed local capture is authoritative while the Firestore observer
    /// catches up. Without this, a transient server-side `nil` can recreate the
    /// Dynamic Island card immediately after the person has completed the ritual.
    static func effectiveHasPostToday(
        hasPostToday: Bool,
        lastCapturedLocalDateID: String?,
        today: LocalDate
    ) -> Bool {
        hasPostToday || lastCapturedLocalDateID == today.docID
    }

    static func decide(
        now: Date,
        timeZone: TimeZone,
        wakeGoalMinutes: Int,
        isAlarmEnabled: Bool,
        hasPostToday: Bool,
        runningActivityLocalDateID: String?
    ) -> Decision {
        guard isAlarmEnabled else {
            return runningActivityLocalDateID != nil ? .end : .leaveAlone
        }
        guard !hasPostToday else {
            return .end
        }

        let today = LocalDate(date: now, timeZone: timeZone)
        let wakeInstant = wakeInstant(wakeGoalMinutes: wakeGoalMinutes, on: today, timeZone: timeZone)
        let windowEnd = wakeInstant.addingTimeInterval(TimeInterval(morningWindowMinutes * 60))

        // A stale activity must not consume today's only reconciliation. If the
        // app first wakes inside today's window, replace yesterday's card in one
        // pass instead of ending it and waiting for another foreground event.
        if let runningActivityLocalDateID, runningActivityLocalDateID != today.docID {
            if now >= wakeInstant, now <= windowEnd {
                return .replace(localDateID: today.docID, wokeAt: wakeInstant)
            }
            return .end
        }

        guard now >= wakeInstant, now <= windowEnd else {
            return runningActivityLocalDateID != nil ? .end : .leaveAlone
        }

        if runningActivityLocalDateID == today.docID {
            return .leaveAlone
        }
        return .start(localDateID: today.docID, wokeAt: wakeInstant)
    }

    private static func wakeInstant(wakeGoalMinutes: Int, on day: LocalDate, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = wakeGoalMinutes / 60
        components.minute = wakeGoalMinutes % 60
        return calendar.date(from: components)!
    }
}

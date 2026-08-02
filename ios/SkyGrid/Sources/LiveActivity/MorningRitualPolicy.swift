import Foundation

/// Every "should the morning-ritual nudge be visible right now" decision lives
/// here, as a pure function — `MorningRitualActivity`/`MorningRitualCoordinator`
/// are thin, untested shims around it, matching the rest of this codebase's
/// policy/shim split (see `AutomaticPaywallPresentationPolicy`, `RestDayPolicy`).
enum MorningRitualPolicy {
    /// How long after the wake time the nudge stays relevant. Past this, a
    /// lingering Lock Screen card would be noise, not a nudge.
    static let morningWindowMinutes = 4 * 60
    /// The single soft follow-up notification, per the chosen design.
    static let followUpDelayMinutes = 20
    /// How many days of one-shot follow-ups stay armed at a time.
    static let followUpWindowDays = 7

    enum Decision: Equatable {
        case start(localDateID: String, wokeAt: Date)
        case end
        case leaveAlone
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
        if let runningActivityLocalDateID, runningActivityLocalDateID != today.docID {
            return .end
        }

        let wakeInstant = wakeInstant(wakeGoalMinutes: wakeGoalMinutes, on: today, timeZone: timeZone)
        let windowEnd = wakeInstant.addingTimeInterval(TimeInterval(morningWindowMinutes * 60))
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

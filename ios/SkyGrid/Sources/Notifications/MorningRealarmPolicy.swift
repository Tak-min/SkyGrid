import Foundation

/// Decides whether a stopped morning alarm re-arms roughly every five minutes,
/// up to twelve attempts (~1 hour) or until the four-hour capture window ends, whichever comes first.
/// Scheduling and cancellation deliberately live elsewhere.
enum MorningRealarmPolicy {
    static let interval: TimeInterval = 5 * 60
    static let maximumAttempts = 12

    enum StopReason: Equatable, Sendable {
        case maximumAttemptsReached
        case dateRolledOver
    }

    enum Decision: Equatable, Sendable {
        case schedule(attempt: Int, fireDate: Date)
        case stop(StopReason)
    }

    /// `attemptCount` is the number of re-alarms already scheduled for this
    /// wake day. `now` is the instant the current alarm was stopped, so invoking
    /// this after each re-alarm fires keeps attempts five minutes apart.
    static func decide(
        attemptCount: Int,
        originalWakeDay: LocalDate,
        now: Date,
        timeZone: TimeZone
    ) -> Decision {
        guard attemptCount < maximumAttempts else {
            return .stop(.maximumAttemptsReached)
        }

        let fireDate = now.addingTimeInterval(interval)
        guard LocalDate(date: fireDate, timeZone: timeZone) == originalWakeDay else {
            return .stop(.dateRolledOver)
        }
        return .schedule(attempt: attemptCount + 1, fireDate: fireDate)
    }
}

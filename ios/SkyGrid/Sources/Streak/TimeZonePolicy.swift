import Foundation

/// A recorded timezone change, as detected by `App/TimeZoneWatcher`. `effectiveFrom`
/// is the local calendar day on which the change was observed.
struct TimeZoneChangeEvent: Sendable, Equatable {
    let effectiveFrom: LocalDate
    let fromIdentifier: String
    let toIdentifier: String
}

/// Turns a timezone-change log into the set of days that should be treated as
/// "exempt" by `StreakCalculator` — days lost or duplicated purely because of travel,
/// not because the user skipped their morning photo (blueprint §3.3).
///
/// Deliberately does NOT handle DST: `Calendar`-based day boundaries already account
/// for DST correctly on their own, so adding DST-specific logic here would be
/// unnecessary complexity solving a problem that doesn't exist (VISION's past-is-
/// never-rewritten policy only needs to protect against actual TimeZone identifier
/// changes from long-haul travel).
enum TimeZonePolicy {
    static func exemptDays(from changeLog: [TimeZoneChangeEvent]) -> Set<LocalDate> {
        Set(changeLog.map(\.effectiveFrom))
    }
}

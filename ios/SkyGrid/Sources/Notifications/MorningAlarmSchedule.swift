import Foundation

struct MorningAlarmSchedule: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var minutesAfterMidnight: Int
    var weekdays: Set<Int>
    var isEnabled: Bool

    static func migrate(morningAlarmEnabled: Bool, wakeGoalMinutes: Int) -> [MorningAlarmSchedule] {
        guard morningAlarmEnabled else { return [] }
        return [MorningAlarmSchedule(
            id: MorningAlarmScheduler.alarmIdentifier,
            minutesAfterMidnight: wakeGoalMinutes,
            weekdays: Set(1...7),
            isEnabled: true
        )]
    }

    static func derivedWakeGoalMinutes(from schedules: [MorningAlarmSchedule]) -> Int? {
        schedules
            .filter(\.isEnabled)
            .map(\.minutesAfterMidnight)
            .min()
    }
}

extension Array where Element == MorningAlarmSchedule {
    /// The first enabled wake time that applies to one calendar weekday. The
    /// follow-up nudge is intentionally once per morning even when several alarms
    /// are used as backups.
    func firstWakeMinutes(on weekday: Int) -> Int? {
        filter { $0.isEnabled && $0.weekdays.contains(weekday) }
            .map(\.minutesAfterMidnight)
            .min()
    }
}

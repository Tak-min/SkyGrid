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

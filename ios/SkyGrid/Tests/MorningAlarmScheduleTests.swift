import XCTest
@testable import SkyGrid

final class MorningAlarmScheduleTests: XCTestCase {
    func testEnabledLegacyAlarmMigratesToOneEverydaySchedule() {
        let schedules = MorningAlarmSchedule.migrate(
            morningAlarmEnabled: true,
            wakeGoalMinutes: 6 * 60 + 30
        )

        XCTAssertEqual(schedules.count, 1)
        let schedule = try! XCTUnwrap(schedules.first)
        XCTAssertEqual(schedule.id, MorningAlarmScheduler.alarmIdentifier)
        XCTAssertEqual(schedule.minutesAfterMidnight, 6 * 60 + 30)
        XCTAssertEqual(schedule.weekdays, Set(1...7))
        XCTAssertTrue(schedule.isEnabled)
    }

    func testDisabledLegacyAlarmMigratesToEmptySchedulesAndHasNoDerivedWakeGoal() {
        let schedules = MorningAlarmSchedule.migrate(
            morningAlarmEnabled: false,
            wakeGoalMinutes: 6 * 60 + 30
        )

        XCTAssertTrue(schedules.isEmpty)
        XCTAssertNil(MorningAlarmSchedule.derivedWakeGoalMinutes(from: schedules))
    }

    func testMigrationIsIdempotent() {
        let first = MorningAlarmSchedule.migrate(morningAlarmEnabled: true, wakeGoalMinutes: 360)
        let second = MorningAlarmSchedule.migrate(morningAlarmEnabled: true, wakeGoalMinutes: 360)

        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(second.first?.id, first.first?.id)
        XCTAssertEqual(second.first?.minutesAfterMidnight, first.first?.minutesAfterMidnight)
        XCTAssertEqual(second.first?.weekdays, first.first?.weekdays)
        XCTAssertEqual(second.first?.isEnabled, first.first?.isEnabled)
    }

    func testDerivedWakeGoalIsEarliestEnabledScheduleOnly() {
        let schedules = [
            MorningAlarmSchedule(id: UUID(), minutesAfterMidnight: 420, weekdays: Set(1...7), isEnabled: true),
            MorningAlarmSchedule(id: UUID(), minutesAfterMidnight: 300, weekdays: Set(1...7), isEnabled: true),
            MorningAlarmSchedule(id: UUID(), minutesAfterMidnight: 240, weekdays: Set(1...7), isEnabled: false)
        ]

        XCTAssertEqual(MorningAlarmSchedule.derivedWakeGoalMinutes(from: schedules), 300)
        XCTAssertNil(MorningAlarmSchedule.derivedWakeGoalMinutes(from: schedules.map {
            MorningAlarmSchedule(
                id: $0.id,
                minutesAfterMidnight: $0.minutesAfterMidnight,
                weekdays: $0.weekdays,
                isEnabled: false
            )
        }))
        XCTAssertNil(MorningAlarmSchedule.derivedWakeGoalMinutes(from: []))
    }

    func testApplyRejectsSixSchedulesWithoutOverwritingSavedSet() async {
        let original = LocalDefaults.morningAlarmSchedules
        defer { LocalDefaults.morningAlarmSchedules = original }
        let saved = MorningAlarmSchedule.migrate(morningAlarmEnabled: true, wakeGoalMinutes: 360)
        LocalDefaults.morningAlarmSchedules = saved
        let tooMany = (0...MorningAlarmScheduler.maximumScheduleCount).map { offset in
            MorningAlarmSchedule(
                id: UUID(),
                minutesAfterMidnight: 360 + offset,
                weekdays: Set(1...7),
                isEnabled: true
            )
        }

        let state = await MorningAlarmScheduler.apply(
            schedules: tooMany,
            useReminderFallback: true
        )

        XCTAssertEqual(state, .failed(.reminder))
        XCTAssertEqual(LocalDefaults.morningAlarmSchedules, saved)
    }
}

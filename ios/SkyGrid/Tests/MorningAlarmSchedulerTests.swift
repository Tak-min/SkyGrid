import Foundation
import Testing
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif
@testable import SkyGrid

@Suite("Morning reminder reconcile plan")
struct MorningAlarmSchedulerTests {
    private func schedule(
        id: UUID = UUID(),
        minutesAfterMidnight: Int = 6 * 60 + 30,
        weekdays: Set<Int> = Set(1...7),
        isEnabled: Bool = true
    ) -> MorningAlarmSchedule {
        MorningAlarmSchedule(
            id: id,
            minutesAfterMidnight: minutesAfterMidnight,
            weekdays: weekdays,
            isEnabled: isEnabled
        )
    }

    private func pending(
        _ identifier: String,
        hour: Int? = 6,
        minute: Int? = 30
    ) -> MorningReminderPendingOccurrence {
        MorningReminderPendingOccurrence(identifier: identifier, hour: hour, minute: minute)
    }

    private func alarm(
        id: UUID,
        hour: Int? = 6,
        minute: Int? = 30,
        weekdays: Set<Int>? = Set(1...7)
    ) -> MorningAlarmKitScheduledAlarm {
        MorningAlarmKitScheduledAlarm(id: id, hour: hour, minute: minute, weekdays: weekdays)
    }

    private func instant(
        hour: Int,
        minute: Int,
        on day: LocalDate,
        timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: day.year,
            month: day.month,
            day: day.day,
            hour: hour,
            minute: minute
        ))!
    }

    @Test("a persisted re-alarm count resets when a new wake day begins")
    func realarmAttemptCountResetsForNewWakeDay() {
        let originalAttemptCount = LocalDefaults.morningRealarmAttemptCount
        let originalWakeDayID = LocalDefaults.morningRealarmWakeDayID
        defer {
            LocalDefaults.morningRealarmAttemptCount = originalAttemptCount
            LocalDefaults.morningRealarmWakeDayID = originalWakeDayID
        }
        let wakeDay = LocalDate(year: 2026, month: 9, day: 5)
        LocalDefaults.morningRealarmAttemptCount = 2
        LocalDefaults.morningRealarmWakeDayID = "2026-09-04"

        #expect(MorningAlarmScheduler.prepareRealarmAttemptCount(for: wakeDay) == 0)
        #expect(LocalDefaults.morningRealarmAttemptCount == 0)
        #expect(LocalDefaults.morningRealarmWakeDayID == "2026-09-04")
    }

    @Test("a re-alarm identifier namespaces its wake day and attempt")
    func realarmIdentifierIncludesWakeDayAndAttempt() {
        #expect(MorningAlarmScheduler.realarmIdentifier(
            wakeDay: LocalDate(year: 2026, month: 9, day: 5),
            attempt: 2
        ) == "com.takmin.skygrid.morning-realarm.2026-09-05.2")
    }

    @Test("one stop plans all three re-alarms at five-minute intervals")
    func realarmOccurrencesPlanThreeAttemptsUpFront() {
        let timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let wakeDay = LocalDate(year: 2026, month: 9, day: 5)
        let stopTime = instant(hour: 6, minute: 0, on: wakeDay, timeZone: timeZone)

        #expect(morningRealarmOccurrences(
            attemptCount: 0,
            originalWakeDay: wakeDay,
            now: stopTime,
            timeZone: timeZone
        ) == [
            MorningRealarmOccurrence(attempt: 1, fireDate: instant(hour: 6, minute: 5, on: wakeDay, timeZone: timeZone)),
            MorningRealarmOccurrence(attempt: 2, fireDate: instant(hour: 6, minute: 10, on: wakeDay, timeZone: timeZone)),
            MorningRealarmOccurrence(attempt: 3, fireDate: instant(hour: 6, minute: 15, on: wakeDay, timeZone: timeZone))
        ])
    }

    @Test("a midnight boundary truncates the up-front re-alarm plan")
    func realarmOccurrencesStopAtLocalDateRollover() {
        let timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let wakeDay = LocalDate(year: 2026, month: 9, day: 5)
        let stopTime = instant(hour: 23, minute: 48, on: wakeDay, timeZone: timeZone)

        #expect(morningRealarmOccurrences(
            attemptCount: 0,
            originalWakeDay: wakeDay,
            now: stopTime,
            timeZone: timeZone
        ) == [
            MorningRealarmOccurrence(attempt: 1, fireDate: instant(hour: 23, minute: 53, on: wakeDay, timeZone: timeZone)),
            MorningRealarmOccurrence(attempt: 2, fireDate: instant(hour: 23, minute: 58, on: wakeDay, timeZone: timeZone))
        ])
    }

    @Test("a persisted schedule set selects the schedule-aware reminder fallback")
    func persistedSchedulesSelectScheduleAwareFallback() {
        let schedules = [
            schedule(minutesAfterMidnight: 390, weekdays: [2, 4]),
            schedule(minutesAfterMidnight: 450, weekdays: [6])
        ]
        let originalSchedules = LocalDefaults.morningAlarmSchedules
        defer { LocalDefaults.morningAlarmSchedules = originalSchedules }
        LocalDefaults.morningAlarmSchedules = schedules

        #expect(MorningAlarmScheduler.reminderFallbackSchedulingInput(wakeGoalMinutes: 360) == .schedules(
            schedules.applyingWakeGoalMinutes(360)
        ))
    }

    @Test("AlarmKit scheduling input updates persisted enabled schedules before reconciling")
    func alarmKitSchedulingInputUpdatesPersistedScheduleTimes() {
        let enabled = schedule(minutesAfterMidnight: 390, weekdays: [2, 4])
        let disabled = schedule(minutesAfterMidnight: 510, weekdays: [6], isEnabled: false)
        let originalSchedules = LocalDefaults.morningAlarmSchedules
        defer { LocalDefaults.morningAlarmSchedules = originalSchedules }
        LocalDefaults.morningAlarmSchedules = [enabled, disabled]

        #expect(MorningAlarmScheduler.alarmKitSchedulingInput(wakeGoalMinutes: 435) == .schedules([
            schedule(id: enabled.id, minutesAfterMidnight: 435, weekdays: [2, 4]),
            disabled
        ]))
        #expect(LocalDefaults.morningAlarmSchedules == [
            schedule(id: enabled.id, minutesAfterMidnight: 435, weekdays: [2, 4]),
            disabled
        ])
    }

    @Test("enabling AlarmKit updates persisted enabled schedules before reconciling")
    func enableUpdatesPersistedAlarmKitScheduleTimes() async {
        let enabled = schedule(minutesAfterMidnight: 390, weekdays: [2, 4])
        let disabled = schedule(minutesAfterMidnight: 510, weekdays: [6], isEnabled: false)
        let originalEnabled = LocalDefaults.morningAlarmEnabled
        let originalBackend = LocalDefaults.morningAlarmBackend
        let originalSchedules = LocalDefaults.morningAlarmSchedules
        defer {
            LocalDefaults.morningAlarmEnabled = originalEnabled
            LocalDefaults.morningAlarmBackend = originalBackend
            LocalDefaults.morningAlarmSchedules = originalSchedules
        }
        LocalDefaults.morningAlarmEnabled = true
        LocalDefaults.morningAlarmSchedules = [enabled, disabled]

        _ = await MorningAlarmScheduler.enable(wakeGoalMinutes: 435)

        #expect(LocalDefaults.morningAlarmSchedules == [
            schedule(id: enabled.id, minutesAfterMidnight: 435, weekdays: [2, 4]),
            disabled
        ])

        if #available(iOS 26.0, *) {
            try? AlarmManager.shared.cancel(id: enabled.id)
        }
        await MorningFollowUpScheduler.cancelAll()
    }

    @Test("enabling reminder fallback updates persisted enabled schedules before reconciling")
    func enableReminderFallbackUpdatesPersistedScheduleTimes() async {
        let enabled = schedule(minutesAfterMidnight: 390, weekdays: [2, 4])
        let disabled = schedule(minutesAfterMidnight: 510, weekdays: [6], isEnabled: false)
        let originalEnabled = LocalDefaults.morningAlarmEnabled
        let originalBackend = LocalDefaults.morningAlarmBackend
        let originalSchedules = LocalDefaults.morningAlarmSchedules
        defer {
            LocalDefaults.morningAlarmEnabled = originalEnabled
            LocalDefaults.morningAlarmBackend = originalBackend
            LocalDefaults.morningAlarmSchedules = originalSchedules
        }
        LocalDefaults.morningAlarmEnabled = true
        LocalDefaults.morningAlarmSchedules = [enabled, disabled]

        _ = await MorningAlarmScheduler.enableReminderFallback(wakeGoalMinutes: 435)

        #expect(LocalDefaults.morningAlarmSchedules == [
            schedule(id: enabled.id, minutesAfterMidnight: 435, weekdays: [2, 4]),
            disabled
        ])

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: enabled.weekdays.map {
            MorningAlarmScheduler.reminderIdentifier(scheduleID: enabled.id, weekday: $0)
        })
        await MorningFollowUpScheduler.cancelAll()
    }

    @Test("applying a new wake time leaves disabled schedules unchanged")
    func applyingWakeGoalMinutesLeavesDisabledSchedulesUnchanged() {
        let enabled = schedule(minutesAfterMidnight: 390)
        let disabled = schedule(minutesAfterMidnight: 510, isEnabled: false)

        #expect([enabled, disabled].applyingWakeGoalMinutes(435) == [
            schedule(id: enabled.id, minutesAfterMidnight: 435),
            disabled
        ])
    }

    @Test("the migrated every-day schedule selects the schedule-aware fallback without changing its follow-up window")
    @MainActor
    func migratedEveryDaySchedulePreservesLegacyFallbackBehavior() {
        let originalEnabled = LocalDefaults.morningAlarmEnabled
        let originalMinutes = LocalDefaults.wakeGoalMinutes
        let originalSchedules = LocalDefaults.morningAlarmSchedules
        let originalVersion = LocalDefaults.morningAlarmScheduleModelVersion
        defer {
            LocalDefaults.morningAlarmEnabled = originalEnabled
            LocalDefaults.wakeGoalMinutes = originalMinutes
            LocalDefaults.morningAlarmSchedules = originalSchedules
            LocalDefaults.morningAlarmScheduleModelVersion = originalVersion
        }

        LocalDefaults.morningAlarmEnabled = true
        LocalDefaults.wakeGoalMinutes = 390
        LocalDefaults.morningAlarmSchedules = []
        LocalDefaults.morningAlarmScheduleModelVersion = 0
        MorningAlarmScheduler.migrateScheduleModelIfNeeded()

        let expected = MorningAlarmSchedule.migrate(morningAlarmEnabled: true, wakeGoalMinutes: 390)
        #expect(MorningAlarmScheduler.reminderFallbackSchedulingInput(wakeGoalMinutes: 390) == .schedules(expected))

        // Tuple arrays aren't Equatable, so compare the fields that actually
        // determine a follow-up's identity and fire time.
        func fingerprint(_ planned: [(wakeDay: LocalDate, deliveryDay: LocalDate, fireComponents: DateComponents)]) -> [String] {
            planned.map { "\($0.wakeDay.docID)|\($0.deliveryDay.docID)|\($0.fireComponents.hour ?? -1):\($0.fireComponents.minute ?? -1)" }
        }
        let scheduleAware = MorningFollowUpScheduler.plannedFollowUps(
            wakeGoalMinutes: 390,
            schedules: expected,
            startingFrom: LocalDate(year: 2026, month: 8, day: 2),
            dayCount: 3
        )
        let legacy = MorningFollowUpScheduler.plannedFollowUps(
            wakeGoalMinutes: 390,
            startingFrom: LocalDate(year: 2026, month: 8, day: 2),
            dayCount: 3
        )
        #expect(fingerprint(scheduleAware) == fingerprint(legacy))
    }

    @Test("no enabled schedules cancel every legacy or multi-schedule request")
    func noSchedulesCancelsEverything() {
        let pending = [
            self.pending(MorningAlarmScheduler.notificationIdentifier),
            self.pending(MorningAlarmScheduler.multiScheduleIdentifierPrefix + "orphan.1")
        ]

        let plan = morningReminderReconcilePlan(schedules: [], currentPendingOccurrences: pending)

        #expect(plan.additions.isEmpty)
        #expect(plan.cancellations == Set(pending.map(\.identifier)))
    }

    @Test("a fully pending every-day schedule is a no-op")
    func fullyPendingScheduleIsNoOp() {
        let entry = schedule()
        let pending = entry.weekdays.map {
            self.pending(MorningAlarmScheduler.reminderIdentifier(scheduleID: entry.id, weekday: $0))
        }

        let plan = morningReminderReconcilePlan(schedules: [entry], currentPendingOccurrences: pending)

        #expect(plan.additions.isEmpty)
        #expect(plan.cancellations.isEmpty)
    }

    @Test("removing a weekday cancels only that occurrence")
    func removedWeekdayIsCancelled() {
        let id = UUID()
        let entry = schedule(id: id, weekdays: [2])
        let monday = MorningAlarmScheduler.reminderIdentifier(scheduleID: id, weekday: 2)
        let tuesday = MorningAlarmScheduler.reminderIdentifier(scheduleID: id, weekday: 3)

        let plan = morningReminderReconcilePlan(
            schedules: [entry],
            currentPendingOccurrences: [pending(monday), pending(tuesday)]
        )

        #expect(plan.additions.isEmpty)
        #expect(plan.cancellations == [tuesday])
    }

    @Test("a new schedule adds each of its selected weekdays")
    func newScheduleAddsItsWeekdays() {
        let existing = schedule(weekdays: [1])
        let added = schedule(weekdays: [2, 4])
        let existingID = MorningAlarmScheduler.reminderIdentifier(scheduleID: existing.id, weekday: 1)

        let plan = morningReminderReconcilePlan(
            schedules: [existing, added],
            currentPendingOccurrences: [pending(existingID)]
        )

        #expect(Set(plan.additions.map(\.identifier)) == [
            MorningAlarmScheduler.reminderIdentifier(scheduleID: added.id, weekday: 2),
            MorningAlarmScheduler.reminderIdentifier(scheduleID: added.id, weekday: 4)
        ])
        #expect(plan.cancellations.isEmpty)
    }

    @Test("the legacy bare identifier is replaced by a multi-schedule occurrence")
    func legacyIdentifierIsCancelledWhenReplacementIsNeeded() {
        let entry = schedule(weekdays: [2])
        let plan = morningReminderReconcilePlan(
            schedules: [entry],
            currentPendingOccurrences: [pending(MorningAlarmScheduler.notificationIdentifier)]
        )

        #expect(plan.additions.map(\.identifier) == [
            MorningAlarmScheduler.reminderIdentifier(scheduleID: entry.id, weekday: 2)
        ])
        #expect(plan.cancellations == [MorningAlarmScheduler.notificationIdentifier])
    }

    @Test("a changed wake time replaces the existing occurrence with the same identifier")
    func changedTimeReplacesExistingOccurrence() {
        let id = UUID()
        let entry = schedule(id: id, minutesAfterMidnight: 400, weekdays: [2])
        let identifier = MorningAlarmScheduler.reminderIdentifier(scheduleID: id, weekday: 2)

        let plan = morningReminderReconcilePlan(
            schedules: [entry],
            currentPendingOccurrences: [pending(identifier, hour: 6, minute: 30)]
        )

        #expect(plan.additions.map(\.identifier) == [identifier])
        #expect(plan.cancellations == [identifier])
        #expect(morningReminderCancellationsAfterAdding(
            plan: plan,
            successfullyAddedIdentifiers: [identifier]
        ).isEmpty)
    }

    @Test("a failed replacement add retains the old occurrence")
    func failedReplacementAddRetainsOldOccurrence() {
        let id = UUID()
        let oldIdentifier = MorningAlarmScheduler.reminderIdentifier(scheduleID: id, weekday: 2)
        let newIdentifier = MorningAlarmScheduler.reminderIdentifier(scheduleID: id, weekday: 3)
        let entry = schedule(id: id, weekdays: [3])
        let plan = morningReminderReconcilePlan(
            schedules: [entry],
            currentPendingOccurrences: [pending(oldIdentifier)]
        )

        #expect(plan.additions.map(\.identifier) == [newIdentifier])
        #expect(plan.cancellations == [oldIdentifier])
        #expect(morningReminderCancellationsAfterAdding(
            plan: plan,
            successfullyAddedIdentifiers: []
        ).isEmpty)
    }

    @Test("a new AlarmKit schedule needs scheduling")
    func newAlarmKitScheduleNeedsAdding() {
        let entry = schedule()

        let plan = morningAlarmKitReconcilePlan(schedules: [entry], currentAlarms: [])

        #expect(plan.additions == [entry])
        #expect(plan.cancellations.isEmpty)
    }

    @Test("an unchanged AlarmKit schedule is a no-op")
    func unchangedAlarmKitScheduleIsNoOp() {
        let entry = schedule(minutesAfterMidnight: 400, weekdays: [2, 4])

        let plan = morningAlarmKitReconcilePlan(
            schedules: [entry],
            currentAlarms: [alarm(id: entry.id, hour: 6, minute: 40, weekdays: [2, 4])]
        )

        #expect(plan.additions.isEmpty)
        #expect(plan.cancellations.isEmpty)
    }

    @Test("an AlarmKit schedule with a changed time is scheduled again")
    func changedAlarmKitTimeNeedsAdding() {
        let entry = schedule(minutesAfterMidnight: 400)

        let plan = morningAlarmKitReconcilePlan(
            schedules: [entry],
            currentAlarms: [alarm(id: entry.id, hour: 6, minute: 30)]
        )

        #expect(plan.additions == [entry])
        #expect(plan.cancellations.isEmpty)
    }

    @Test("an AlarmKit schedule with changed weekdays is scheduled again")
    func changedAlarmKitWeekdaysNeedAdding() {
        let entry = schedule(weekdays: [2, 4])

        let plan = morningAlarmKitReconcilePlan(
            schedules: [entry],
            currentAlarms: [alarm(id: entry.id, weekdays: [2, 3])]
        )

        #expect(plan.additions == [entry])
        #expect(plan.cancellations.isEmpty)
    }

    @Test("a disabled schedule cancels its current AlarmKit alarm")
    func disabledAlarmKitScheduleNeedsCancelling() {
        let entry = schedule(isEnabled: false)

        let plan = morningAlarmKitReconcilePlan(
            schedules: [entry],
            currentAlarms: [alarm(id: entry.id)]
        )

        #expect(plan.additions.isEmpty)
        #expect(plan.cancellations == [entry.id])
    }

    @Test("AlarmKit reconciliation mixes additions cancellations and unchanged entries")
    func mixedAlarmKitReconciliation() {
        let unchanged = schedule(minutesAfterMidnight: 400, weekdays: [2])
        let changed = schedule(minutesAfterMidnight: 450, weekdays: [4])
        let added = schedule(minutesAfterMidnight: 500, weekdays: [6])
        let disabled = schedule(isEnabled: false)

        let plan = morningAlarmKitReconcilePlan(
            schedules: [unchanged, changed, added, disabled],
            currentAlarms: [
                alarm(id: unchanged.id, hour: 6, minute: 40, weekdays: [2]),
                alarm(id: changed.id, hour: 6, minute: 30, weekdays: [4]),
                alarm(id: disabled.id)
            ]
        )

        #expect(plan.additions == [changed, added])
        #expect(plan.cancellations == [disabled.id])
    }
}

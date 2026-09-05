import Foundation
import Testing
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
        })

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
}

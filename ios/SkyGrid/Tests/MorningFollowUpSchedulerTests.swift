import Foundation
import Testing
@testable import SkyGrid

@Suite("MorningFollowUpScheduler")
struct MorningFollowUpSchedulerTests {
    private let today = LocalDate(year: 2026, month: 8, day: 2)

    @Test("identifier is keyed by the delivery day, prefixed for bulk cancellation")
    func identifierIsPrefixedAndDateKeyed() {
        let id = MorningFollowUpScheduler.identifier(for: today)
        #expect(id == "com.takmin.skygrid.morning-followup.2026-08-02")
        #expect(id.hasPrefix(MorningFollowUpScheduler.identifierPrefix))
    }

    @Test("plans one follow-up per day for the requested window, delivery day preserved")
    func plansOnePerDay() {
        let planned = MorningFollowUpScheduler.plannedFollowUps(wakeGoalMinutes: 360, startingFrom: today, dayCount: 3)
        #expect(planned.map(\.wakeDay) == [today, today.adding(days: 1), today.adding(days: 2)])
        #expect(planned.map(\.deliveryDay) == [today, today.adding(days: 1), today.adding(days: 2)])
        #expect(planned[0].fireComponents.hour == 6)
        #expect(planned[0].fireComponents.minute == 20)
        #expect(planned[0].fireComponents.day == today.day)
    }

    @Test("does not plan a follow-up on a weekday no enabled alarm covers")
    func excludesUnscheduledWeekdays() {
        // 2026-08-02 is Sunday (weekday 1); this schedule only covers Monday.
        let mondayOnly = MorningAlarmSchedule(
            id: UUID(),
            minutesAfterMidnight: 360,
            weekdays: [2],
            isEnabled: true
        )

        let planned = MorningFollowUpScheduler.plannedFollowUps(
            wakeGoalMinutes: 360,
            schedules: [mondayOnly],
            startingFrom: today,
            dayCount: 2
        )

        #expect(planned.map(\.wakeDay) == [today.adding(days: 1)])
    }

    @Test("an every-day schedule preserves the legacy every-day window")
    func everyDaySchedulePreservesLegacyBehavior() {
        let everyDay = MorningAlarmSchedule(
            id: UUID(),
            minutesAfterMidnight: 360,
            weekdays: Set(1...7),
            isEnabled: true
        )
        let legacy = MorningFollowUpScheduler.plannedFollowUps(
            wakeGoalMinutes: 360,
            startingFrom: today,
            dayCount: 3
        )
        let scheduleAware = MorningFollowUpScheduler.plannedFollowUps(
            wakeGoalMinutes: 360,
            schedules: [everyDay],
            startingFrom: today,
            dayCount: 3
        )

        #expect(scheduleAware.map(\.wakeDay) == legacy.map(\.wakeDay))
        #expect(scheduleAware.map(\.deliveryDay) == legacy.map(\.deliveryDay))
        #expect(scheduleAware.map(\.fireComponents) == legacy.map(\.fireComponents))
    }

    @Test("a wake time within followUpDelayMinutes of midnight is keyed to its delivery day")
    func crossesMidnightAndUsesDeliveryDayIdentity() {
        let lateWake = 23 * 60 + 50 // 23:50
        let planned = MorningFollowUpScheduler.plannedFollowUps(wakeGoalMinutes: lateWake, startingFrom: today, dayCount: 1)
        let (wakeDay, _, fireComponents) = planned[0]

        #expect(wakeDay == today)
        #expect(planned[0].deliveryDay == today.adding(days: 1))
        #expect(MorningFollowUpScheduler.identifier(for: planned[0].deliveryDay) == "com.takmin.skygrid.morning-followup.2026-08-03")
        #expect(fireComponents.day == today.adding(days: 1).day)
        #expect(fireComponents.hour == 0)
        #expect(fireComponents.minute == 10)
    }

    @Test("suppresses only a same-day foreground follow-up after a local capture")
    func suppressesOnlyMatchingForegroundFollowUp() {
        let todayID = today.docID
        #expect(MorningFollowUpScheduler.shouldSuppressForegroundDelivery(
            identifier: MorningFollowUpScheduler.identifier(for: today),
            lastCapturedLocalDateID: todayID
        ))
        #expect(!MorningFollowUpScheduler.shouldSuppressForegroundDelivery(
            identifier: MorningFollowUpScheduler.identifier(for: today.adding(days: 1)),
            lastCapturedLocalDateID: todayID
        ))
        #expect(!MorningFollowUpScheduler.shouldSuppressForegroundDelivery(
            identifier: "unrelated-notification",
            lastCapturedLocalDateID: todayID
        ))
    }
}

import Foundation
import Testing
@testable import SkyGrid

@Suite("MorningFollowUpScheduler")
struct MorningFollowUpSchedulerTests {
    private let today = LocalDate(year: 2026, month: 8, day: 2)

    @Test("identifier is keyed by the wake day, prefixed for bulk cancellation")
    func identifierIsPrefixedAndDateKeyed() {
        let id = MorningFollowUpScheduler.identifier(for: today)
        #expect(id == "com.takmin.skygrid.morning-followup.2026-08-02")
        #expect(id.hasPrefix(MorningFollowUpScheduler.identifierPrefix))
    }

    @Test("plans one follow-up per day for the requested window, wake day preserved")
    func plansOnePerDay() {
        let planned = MorningFollowUpScheduler.plannedFollowUps(wakeGoalMinutes: 360, startingFrom: today, dayCount: 3)
        #expect(planned.map(\.wakeDay) == [today, today.adding(days: 1), today.adding(days: 2)])
        #expect(planned[0].fireComponents.hour == 6)
        #expect(planned[0].fireComponents.minute == 20)
        #expect(planned[0].fireComponents.day == today.day)
    }

    @Test("a wake time within followUpDelayMinutes of midnight fires the next calendar day, keyed to the wake day")
    func crossesMidnightButKeepsWakeDayIdentity() {
        let lateWake = 23 * 60 + 50 // 23:50
        let planned = MorningFollowUpScheduler.plannedFollowUps(wakeGoalMinutes: lateWake, startingFrom: today, dayCount: 1)
        let (wakeDay, fireComponents) = planned[0]

        #expect(wakeDay == today)
        #expect(fireComponents.day == today.adding(days: 1).day)
        #expect(fireComponents.hour == 0)
        #expect(fireComponents.minute == 10)
    }
}

import Foundation
import Testing
@testable import SkyGrid

@Suite("MorningRitualPolicy")
struct MorningRitualPolicyTests {
    private let timeZone = TimeZone(identifier: "UTC")!
    private let wakeGoalMinutes = 360 // 6:00
    private let today = LocalDate(year: 2026, month: 8, day: 2)

    private func instant(hour: Int, minute: Int, day: LocalDate? = nil) -> Date {
        let day = day ?? today
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = hour
        components.minute = minute
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: components)!
    }

    @Test("disabled alarm ends a running activity but leaves nothing alone otherwise")
    func disabledAlarmEndsRunningActivity() {
        #expect(MorningRitualPolicy.decide(
            now: instant(hour: 6, minute: 5), timeZone: timeZone, wakeGoalMinutes: wakeGoalMinutes,
            isAlarmEnabled: false, hasPostToday: false, runningActivityLocalDateID: today.docID
        ) == .end)
        #expect(MorningRitualPolicy.decide(
            now: instant(hour: 6, minute: 5), timeZone: timeZone, wakeGoalMinutes: wakeGoalMinutes,
            isAlarmEnabled: false, hasPostToday: false, runningActivityLocalDateID: nil
        ) == .leaveAlone)
    }

    @Test("a post today always ends the activity")
    func postTodayEnds() {
        #expect(MorningRitualPolicy.decide(
            now: instant(hour: 6, minute: 5), timeZone: timeZone, wakeGoalMinutes: wakeGoalMinutes,
            isAlarmEnabled: true, hasPostToday: true, runningActivityLocalDateID: today.docID
        ) == .end)
    }

    @Test("a leftover activity from a previous day is ended")
    func leftoverYesterdayEnds() {
        let yesterday = today.adding(days: -1)
        #expect(MorningRitualPolicy.decide(
            now: instant(hour: 6, minute: 5), timeZone: timeZone, wakeGoalMinutes: wakeGoalMinutes,
            isAlarmEnabled: true, hasPostToday: false, runningActivityLocalDateID: yesterday.docID
        ) == .end)
    }

    @Test("before the wake time, nothing starts")
    func beforeWakeTimeLeavesAlone() {
        #expect(MorningRitualPolicy.decide(
            now: instant(hour: 5, minute: 59), timeZone: timeZone, wakeGoalMinutes: wakeGoalMinutes,
            isAlarmEnabled: true, hasPostToday: false, runningActivityLocalDateID: nil
        ) == .leaveAlone)
    }

    @Test("after the morning window, a running activity ends and nothing new starts")
    func afterWindowEnds() {
        #expect(MorningRitualPolicy.decide(
            now: instant(hour: 10, minute: 1), timeZone: timeZone, wakeGoalMinutes: wakeGoalMinutes,
            isAlarmEnabled: true, hasPostToday: false, runningActivityLocalDateID: today.docID
        ) == .end)
        #expect(MorningRitualPolicy.decide(
            now: instant(hour: 10, minute: 1), timeZone: timeZone, wakeGoalMinutes: wakeGoalMinutes,
            isAlarmEnabled: true, hasPostToday: false, runningActivityLocalDateID: nil
        ) == .leaveAlone)
    }

    @Test("inside the window with nothing running, starts today's activity")
    func startsInsideWindow() {
        let decision = MorningRitualPolicy.decide(
            now: instant(hour: 6, minute: 5), timeZone: timeZone, wakeGoalMinutes: wakeGoalMinutes,
            isAlarmEnabled: true, hasPostToday: false, runningActivityLocalDateID: nil
        )
        #expect(decision == .start(localDateID: today.docID, wokeAt: instant(hour: 6, minute: 0)))
    }

    @Test("inside the window with today's activity already running, leaves it alone")
    func idempotentWhenAlreadyRunning() {
        #expect(MorningRitualPolicy.decide(
            now: instant(hour: 6, minute: 5), timeZone: timeZone, wakeGoalMinutes: wakeGoalMinutes,
            isAlarmEnabled: true, hasPostToday: false, runningActivityLocalDateID: today.docID
        ) == .leaveAlone)
    }
}

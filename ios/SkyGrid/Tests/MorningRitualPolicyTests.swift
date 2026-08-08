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

    @Test("only the Live Activity capture URL requests the camera")
    @MainActor
    func liveActivityCaptureURLRoutesToCamera() {
        let router = AppRouter()
        router.handle(url: URL(string: "skygrid://capture")!)
        #expect(router.pendingRoute == .camera)

        router.pendingRoute = nil
        router.handle(url: URL(string: "skygrid://unrelated")!)
        #expect(router.pendingRoute == nil)
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

    @Test("a durable local capture ends the activity while the server observer catches up")
    func localCaptureAlsoCountsAsPostedToday() {
        let effectiveHasPost = MorningRitualPolicy.effectiveHasPostToday(
            hasPostToday: false,
            lastCapturedLocalDateID: today.docID,
            today: today
        )
        #expect(effectiveHasPost)
        #expect(MorningRitualPolicy.decide(
            now: instant(hour: 6, minute: 5), timeZone: timeZone, wakeGoalMinutes: wakeGoalMinutes,
            isAlarmEnabled: true, hasPostToday: effectiveHasPost, runningActivityLocalDateID: today.docID
        ) == .end)
    }

    @Test("a leftover activity is replaced with today's card in one reconciliation")
    func leftoverYesterdayIsReplacedInsideWindow() {
        let yesterday = today.adding(days: -1)
        #expect(MorningRitualPolicy.decide(
            now: instant(hour: 6, minute: 5), timeZone: timeZone, wakeGoalMinutes: wakeGoalMinutes,
            isAlarmEnabled: true, hasPostToday: false, runningActivityLocalDateID: yesterday.docID
        ) == .replace(localDateID: today.docID, wokeAt: instant(hour: 6, minute: 0)))
    }

    @Test("a leftover activity outside today's window ends without replacement")
    func leftoverYesterdayEndsOutsideWindow() {
        let yesterday = today.adding(days: -1)
        #expect(MorningRitualPolicy.decide(
            now: instant(hour: 11, minute: 0), timeZone: timeZone, wakeGoalMinutes: wakeGoalMinutes,
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

import Foundation
import Testing
@testable import SkyGrid

@Suite("Morning re-alarm policy")
struct MorningRealarmPolicyTests {
    private let timeZone = TimeZone(identifier: "Asia/Tokyo")!
    private let wakeDay = LocalDate(year: 2026, month: 9, day: 5)

    private func instant(hour: Int, minute: Int, on day: LocalDate? = nil) -> Date {
        let day = day ?? wakeDay
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

    @Test("schedules exactly maximumAttempts re-alarms five minutes apart, then stops")
    func schedulesMaximumAttemptsAndNeverOneMore() {
        var decisionTime = instant(hour: 6, minute: 0)
        for attempt in 1...MorningRealarmPolicy.maximumAttempts {
            let expectedFire = instant(hour: 6, minute: 5 * attempt)
            #expect(MorningRealarmPolicy.decide(
                attemptCount: attempt - 1,
                originalWakeDay: wakeDay,
                now: decisionTime,
                timeZone: timeZone
            ) == .schedule(attempt: attempt, fireDate: expectedFire))
            decisionTime = expectedFire
        }
        #expect(MorningRealarmPolicy.decide(
            attemptCount: MorningRealarmPolicy.maximumAttempts,
            originalWakeDay: wakeDay,
            now: decisionTime,
            timeZone: timeZone
        ) == .stop(.maximumAttemptsReached))
    }

    @Test("does not schedule an attempt whose fire time rolls into the next local date")
    func stopsAtLocalDateRollover() {
        #expect(MorningRealarmPolicy.decide(
            attemptCount: 2,
            originalWakeDay: wakeDay,
            now: instant(hour: 23, minute: 58),
            timeZone: timeZone
        ) == .stop(.dateRolledOver))
    }
}

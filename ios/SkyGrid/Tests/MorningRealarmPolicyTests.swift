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

    @Test("schedules exactly three re-alarms five minutes apart")
    func schedulesThreeAttemptsAndNeverAFourth() {
        let firstStop = instant(hour: 6, minute: 0)
        let firstFire = instant(hour: 6, minute: 5)
        let secondFire = instant(hour: 6, minute: 10)
        let thirdFire = instant(hour: 6, minute: 15)

        #expect(MorningRealarmPolicy.decide(
            attemptCount: 0,
            originalWakeDay: wakeDay,
            now: firstStop,
            timeZone: timeZone
        ) == .schedule(attempt: 1, fireDate: firstFire))
        #expect(MorningRealarmPolicy.decide(
            attemptCount: 1,
            originalWakeDay: wakeDay,
            now: firstFire,
            timeZone: timeZone
        ) == .schedule(attempt: 2, fireDate: secondFire))
        #expect(MorningRealarmPolicy.decide(
            attemptCount: 2,
            originalWakeDay: wakeDay,
            now: secondFire,
            timeZone: timeZone
        ) == .schedule(attempt: 3, fireDate: thirdFire))
        #expect(MorningRealarmPolicy.decide(
            attemptCount: 3,
            originalWakeDay: wakeDay,
            now: thirdFire,
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

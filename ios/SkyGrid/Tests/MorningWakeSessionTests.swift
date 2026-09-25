import Foundation
import Testing
@testable import SkyGrid

@Suite("Capture-required morning session")
struct MorningWakeSessionTests {
    private let timeZone = TimeZone(identifier: "Asia/Tokyo")!
    private let wakeDay = LocalDate(year: 2026, month: 9, day: 8)

    private func instant(hour: Int, minute: Int, day: Int = 8) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: 2026, month: 9, day: day, hour: hour, minute: minute
        ))!
    }

    private func session(
        deadline: Date,
        phase: MorningWakeSession.Phase = .awaitingCapture,
        retries: [MorningWakeRetry] = []
    ) -> MorningWakeSession {
        MorningWakeSession(
            wakeDayID: wakeDay.docID,
            sourceAlarmID: UUID(),
            startedAt: instant(hour: 6, minute: 0),
            deadline: deadline,
            phase: phase,
            pendingRetries: retries
        )
    }

    @Test("new session ends after four hours on an ordinary morning")
    func startsWithFourHourDeadline() {
        let now = instant(hour: 6, minute: 0)
        #expect(morningWakeSessionDecision(
            existing: nil,
            wakeDay: wakeDay,
            now: now,
            timeZone: timeZone,
            hasCaptured: false
        ) == .start(deadline: instant(hour: 10, minute: 0)))
    }

    @Test("deadline never crosses the local day boundary")
    func deadlineStopsAtMidnight() {
        let now = instant(hour: 23, minute: 0)
        #expect(morningWakeSessionDecision(
            existing: nil,
            wakeDay: wakeDay,
            now: now,
            timeZone: timeZone,
            hasCaptured: false
        ) == .start(deadline: instant(hour: 0, minute: 0, day: 9)))
    }

    @Test("durable capture and expired sessions both clear")
    func captureOrExpiryClears() {
        let active = session(deadline: instant(hour: 10, minute: 0))
        #expect(morningWakeSessionDecision(
            existing: active,
            wakeDay: wakeDay,
            now: instant(hour: 6, minute: 5),
            timeZone: timeZone,
            hasCaptured: true
        ) == .clear(active))
        #expect(morningWakeSessionDecision(
            existing: active,
            wakeDay: wakeDay,
            now: instant(hour: 10, minute: 0),
            timeZone: timeZone,
            hasCaptured: false
        ) == .clear(active))
    }

    @Test("consuming one retry retains two and replenishes the rolling horizon")
    func retryHorizonReplenishes() {
        let consumed = MorningWakeRetry(id: UUID(), fireDate: instant(hour: 6, minute: 5))
        let second = MorningWakeRetry(id: UUID(), fireDate: instant(hour: 6, minute: 10))
        let third = MorningWakeRetry(id: UUID(), fireDate: instant(hour: 6, minute: 15))
        let plan = morningWakeRetryDates(
            pending: [consumed, second, third],
            consumedAlarmID: consumed.id,
            now: instant(hour: 6, minute: 5),
            deadline: instant(hour: 10, minute: 0),
            desiredPendingCount: 3
        )

        #expect(plan.retained == [second, third])
        #expect(plan.additions == [instant(hour: 6, minute: 20)])
    }

    @Test("production default front-loads twelve reservations within a four-hour window")
    func productionDefaultFrontLoadsTwelveReservations() {
        let plan = morningWakeRetryDates(
            pending: [],
            consumedAlarmID: nil,
            now: instant(hour: 6, minute: 0),
            deadline: instant(hour: 10, minute: 0)
        )
        #expect(plan.retained.isEmpty)
        #expect(plan.additions.count == 12)
        #expect(plan.additions.first == instant(hour: 6, minute: 5))
        #expect(plan.additions.last == instant(hour: 7, minute: 0))
    }

    @Test("rolling horizon stops adding at its deadline")
    func retryHorizonHonorsDeadline() {
        let consumed = MorningWakeRetry(id: UUID(), fireDate: instant(hour: 9, minute: 55))
        let plan = morningWakeRetryDates(
            pending: [consumed],
            consumedAlarmID: consumed.id,
            now: instant(hour: 9, minute: 55),
            deadline: instant(hour: 10, minute: 0)
        )
        #expect(plan.retained.isEmpty)
        #expect(plan.additions.isEmpty)
    }
}

import Testing
@testable import SkyGrid

@Suite("TimeZonePolicy")
struct TimeZonePolicyTests {
    @Test("derives exempt days from the change log's effective dates")
    func derivesExemptDaysFromLog() {
        let changeDay = LocalDate(year: 2026, month: 7, day: 15)
        let log = [TimeZoneChangeEvent(effectiveFrom: changeDay, fromIdentifier: "Asia/Tokyo", toIdentifier: "America/Los_Angeles")]
        #expect(TimeZonePolicy.exemptDays(from: log) == [changeDay])
    }

    @Test("empty log yields no exempt days")
    func emptyLogYieldsNoExemptDays() {
        #expect(TimeZonePolicy.exemptDays(from: []).isEmpty)
    }
}

@Suite("RestDayPolicy")
struct RestDayPolicyTests {
    // Monday 2026-07-27 through Sunday 2026-08-02 is one fixed calendar-week block.
    private let monday = LocalDate(year: 2026, month: 7, day: 27)

    @Test("a single missed day in a week is exempted")
    func singleMissedDayIsExempted() {
        // Posted every day this week except Wednesday.
        let posted = (0..<7).map { monday.adding(days: $0) }.filter { $0 != monday.adding(days: 2) }
        let exempt = RestDayPolicy.exemptDays(postedDays: posted, today: monday.adding(days: 6))
        #expect(exempt == [monday.adding(days: 2)])
    }

    @Test("only the first missed day in a week is exempted, never both")
    func onlyOneMissedDayPerWeekIsExempted() {
        // Missed both Tuesday and Thursday this week.
        let posted = (0..<7).map { monday.adding(days: $0) }
            .filter { $0 != monday.adding(days: 1) && $0 != monday.adding(days: 3) }
        let exempt = RestDayPolicy.exemptDays(postedDays: posted, today: monday.adding(days: 6))
        #expect(exempt == [monday.adding(days: 1)])
    }

    @Test("a missed day is never exempted twice by checking from two different weeks")
    func missedDayIsNotDoubleCountedAcrossSlidingWindows() {
        // A sliding 7-day window would let the same missed Sunday appear in two
        // different "weeks" depending on which day you check from — a fixed
        // Monday-Sunday block must not do that: checking from the following Monday
        // still exempts only the one missed day, not a second one for that block.
        let missedSunday = monday.adding(days: -1)
        let posted = (-8...6).map { monday.adding(days: $0) }.filter { $0 != missedSunday }
        let exempt = RestDayPolicy.exemptDays(postedDays: posted, today: monday.adding(days: 6))
        #expect(exempt.contains(missedSunday))
        #expect(exempt.count == 1)
    }

    @Test("a week with no missed days exempts nothing")
    func fullWeekExemptsNothing() {
        let posted = (0..<7).map { monday.adding(days: $0) }
        #expect(RestDayPolicy.exemptDays(postedDays: posted, today: monday.adding(days: 6)).isEmpty)
    }

    @Test("no posted history yields no exempt days")
    func noHistoryYieldsNoExemptDays() {
        #expect(RestDayPolicy.exemptDays(postedDays: [], today: monday).isEmpty)
    }

    @Test("a rest day is never granted for a day that hasn't happened yet")
    func futureDaysAreNeverExempted() {
        let posted = [monday]
        let exempt = RestDayPolicy.exemptDays(postedDays: posted, today: monday)
        #expect(!exempt.contains(monday.adding(days: 1)))
    }
}

@Suite("ProGate")
struct ProGateTests {
    @Test("free archive includes exactly the last 30 local days")
    func limitsFreeArchiveWindow() {
        let today = LocalDate(year: 2026, month: 7, day: 30)

        #expect(ProGate.isWithinFreeArchiveWindow(today.adding(days: -29), today: today))
        #expect(!ProGate.isWithinFreeArchiveWindow(today.adding(days: -30), today: today))
        #expect(!ProGate.isWithinFreeArchiveWindow(today.adding(days: 1), today: today))
    }
}

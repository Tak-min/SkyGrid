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
    @Test("free tier allows exactly one rest day per week")
    func freeTierAllowsOneRestDay() {
        #expect(RestDayPolicy.hasRestDayAvailable(usedRestDaysThisWeek: 0, isPro: false))
        #expect(!RestDayPolicy.hasRestDayAvailable(usedRestDaysThisWeek: 1, isPro: false))
    }

    @Test("pro tier is unrestricted")
    func proTierIsUnrestricted() {
        #expect(RestDayPolicy.hasRestDayAvailable(usedRestDaysThisWeek: 5, isPro: true))
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

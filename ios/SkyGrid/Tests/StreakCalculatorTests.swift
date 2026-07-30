import Testing
@testable import SkyGrid

@Suite("StreakCalculator")
struct StreakCalculatorTests {
    private let day1 = LocalDate(year: 2026, month: 7, day: 1)
    private let day2 = LocalDate(year: 2026, month: 7, day: 2)
    private let day3 = LocalDate(year: 2026, month: 7, day: 3)
    private let day4 = LocalDate(year: 2026, month: 7, day: 4)

    @Test("counts consecutive posted days ending today")
    func countsConsecutiveDays() {
        let summary = StreakCalculator.summarize(postedDays: [day1, day2, day3], today: day3)
        #expect(summary.currentStreak == 3)
        #expect(summary.hasPostedToday)
    }

    @Test("grace: streak stays alive if yesterday was posted but today isn't yet")
    func graceBeforeTodaysPost() {
        let summary = StreakCalculator.summarize(postedDays: [day1, day2, day3], today: day4)
        #expect(summary.currentStreak == 3)
        #expect(!summary.hasPostedToday)
    }

    @Test("a gap stops the count from reaching further back, even mid-chain")
    func gapLimitsStreakDepth() {
        // day2 is missing (not posted, not exempt): the chain walking back from
        // day3 must stop there, so day1 (before the gap) must NOT be counted —
        // the streak is 1 (day3 alone), not 2.
        let summary = StreakCalculator.summarize(postedDays: [day1, day3], today: day4)
        #expect(summary.currentStreak == 1)
    }

    @Test("breaks to zero when the most recent post is more than a day stale")
    func breaksToZeroWhenStale() {
        let summary = StreakCalculator.summarize(postedDays: [day1], today: day4)
        #expect(summary.currentStreak == 0)
        #expect(!summary.hasPostedToday)
    }

    @Test("exempt day preserves the chain without incrementing the count")
    func exemptDayPreservesChainButDoesNotCount() {
        // day2 is exempt (e.g. a timezone-change skip or a used rest day): posted
        // day1 and day3/day4, missing day2 — should NOT break the streak, and the
        // exempt day itself shouldn't add to the numeric count.
        let summary = StreakCalculator.summarize(
            postedDays: [day1, day3, day4],
            today: day4,
            exemptDays: [day2]
        )
        #expect(summary.currentStreak == 3)
    }

    @Test("zero streak when nothing posted and no grace applies")
    func zeroWhenNothingPosted() {
        let summary = StreakCalculator.summarize(postedDays: [], today: day1)
        #expect(summary.currentStreak == 0)
        #expect(!summary.hasPostedToday)
    }
}

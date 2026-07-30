import Testing
@testable import SkyGrid

@Suite("WeekRhythmCalculator")
struct WeekRhythmCalculatorTests {
    @Test("produces exactly 7 days ending today")
    func producesSevenDaysEndingToday() {
        let today = LocalDate(year: 2026, month: 7, day: 29)
        let rhythm = WeekRhythmCalculator.summarize(postedDays: [], today: today)
        #expect(rhythm.days.count == 7)
        #expect(rhythm.days.last?.date == today)
        #expect(rhythm.days.last?.isToday == true)
        #expect(rhythm.days.dropLast().allSatisfy { !$0.isToday })
    }

    @Test("postedCount reflects only days actually posted")
    func postedCountReflectsActualPosts() {
        let today = LocalDate(year: 2026, month: 7, day: 29)
        let posted = [today, today.adding(days: -1), today.adding(days: -3)]
        let rhythm = WeekRhythmCalculator.summarize(postedDays: posted, today: today)
        #expect(rhythm.postedCount == 3)
    }
}

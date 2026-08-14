import Foundation
import Testing
@testable import SkyGrid

@Suite("WeekRhythmCalculator")
struct WeekRhythmCalculatorTests {
    private static func post(on date: LocalDate, thumbPath: String = "thumb.jpg") -> SkyPost {
        SkyPost(
            ownerUid: "uid",
            localDate: date,
            capturedAt: Date(),
            uploadedAt: Date(),
            imagePath: "image.jpg",
            thumbPath: thumbPath,
            skyColor: SkyColor(uncheckedHex: "#9DB7C5"),
            minutesFromGoal: 0,
            reactions: [:]
        )
    }

    @Test("produces exactly 7 days ending today")
    func producesSevenDaysEndingToday() {
        let today = LocalDate(year: 2026, month: 7, day: 29)
        let rhythm = WeekRhythmCalculator.summarize(posts: [], today: today)
        #expect(rhythm.days.count == 7)
        #expect(rhythm.days.last?.date == today)
        #expect(rhythm.days.last?.isToday == true)
        #expect(rhythm.days.dropLast().allSatisfy { !$0.isToday })
    }

    @Test("postedCount reflects only days actually posted")
    func postedCountReflectsActualPosts() {
        let today = LocalDate(year: 2026, month: 7, day: 29)
        let posted = [today, today.adding(days: -1), today.adding(days: -3)].map { Self.post(on: $0) }
        let rhythm = WeekRhythmCalculator.summarize(posts: posted, today: today)
        #expect(rhythm.postedCount == 3)
    }

    @Test("a posted day carries its post's thumbPath for photo display")
    func postedDayCarriesThumbPath() {
        let today = LocalDate(year: 2026, month: 7, day: 29)
        let posted = [Self.post(on: today, thumbPath: "posts/uid/2026-07-29/abc_thumb.jpg")]
        let rhythm = WeekRhythmCalculator.summarize(posts: posted, today: today)
        #expect(rhythm.days.last?.thumbPath == "posts/uid/2026-07-29/abc_thumb.jpg")
    }

    @Test("an unposted day carries no thumbPath")
    func unpostedDayCarriesNoThumbPath() {
        let today = LocalDate(year: 2026, month: 7, day: 29)
        let rhythm = WeekRhythmCalculator.summarize(posts: [], today: today)
        #expect(rhythm.days.allSatisfy { $0.thumbPath == nil })
    }
}

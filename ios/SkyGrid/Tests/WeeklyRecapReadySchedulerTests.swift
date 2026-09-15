import Foundation
import Testing
@testable import SkyGrid

@Suite("WeeklyRecapReadyScheduler")
struct WeeklyRecapReadySchedulerTests {
    private let today = LocalDate(year: 2026, month: 8, day: 9)

    @Test("identifier is keyed by the end date, prefixed for bulk cancellation")
    func identifierIsPrefixedAndDateKeyed() {
        let id = WeeklyRecapReadyScheduler.identifier(for: today)
        #expect(id == "com.takmin.skygrid.weekly-recap-ready.2026-08-09")
        #expect(id.hasPrefix(WeeklyRecapReadyScheduler.identifierPrefix))
    }

    @Test("detects when recap is ready (all 7 days posted)")
    func detectsRecapReady() {
        // Create a week with all 7 days posted
        let allDaysPosted = (0..<7).map { offset -> WeekRhythmDay in
            let date = today.adding(days: offset - 6)
            return WeekRhythmDay(
                date: date,
                hasPosted: true,
                isToday: offset == 6,
                post: SkyPost.fixture(localDate: date)
            )
        }
        let rhythm = WeekRhythm(days: allDaysPosted)

        #expect(WeeklyRecapReadyScheduler.isRecapNewlyReady(rhythm))
    }

    @Test("detects when recap is not ready (missing one day)")
    func detectsRecapNotReady() {
        // Create a week with 6 days posted (missing one)
        let sixDaysPosted = (0..<7).map { offset -> WeekRhythmDay in
            let date = today.adding(days: offset - 6)
            let hasPosted = offset != 3 // Skip one day
            return WeekRhythmDay(
                date: date,
                hasPosted: hasPosted,
                isToday: offset == 6,
                post: hasPosted ? SkyPost.fixture(localDate: date) : nil
            )
        }
        let rhythm = WeekRhythm(days: sixDaysPosted)

        #expect(!WeeklyRecapReadyScheduler.isRecapNewlyReady(rhythm))
    }

    @Test("detects when recap is not ready (no posts)")
    func detectsRecapNotReadyWithNoPosts() {
        let noDaysPosted = (0..<7).map { offset -> WeekRhythmDay in
            let date = today.adding(days: offset - 6)
            return WeekRhythmDay(
                date: date,
                hasPosted: false,
                isToday: offset == 6,
                post: nil
            )
        }
        let rhythm = WeekRhythm(days: noDaysPosted)

        #expect(!WeeklyRecapReadyScheduler.isRecapNewlyReady(rhythm))
    }
}

// Helper extension for test fixtures
extension SkyPost {
    static func fixture(localDate: LocalDate) -> SkyPost {
        SkyPost(
            ownerUid: "uid",
            localDate: localDate,
            capturedAt: Date(),
            uploadedAt: Date(),
            imagePath: "image.jpg",
            thumbPath: "thumb.jpg",
            skyColor: SkyColor(uncheckedHex: "#9DB7C5"),
            minutesFromGoal: 0,
            reactions: [:]
        )
    }
}

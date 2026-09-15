import Foundation
import Testing
@testable import SkyGrid

@Suite("StreakAboutToBreakScheduler")
struct StreakAboutToBreakSchedulerTests {
    private let today = LocalDate(year: 2026, month: 8, day: 2)

    @Test("identifier is keyed by the date, prefixed for bulk cancellation")
    func identifierIsPrefixedAndDateKeyed() {
        let id = StreakAboutToBreakScheduler.identifier(for: today)
        #expect(id == "com.takmin.skygrid.streak-about-to-break.2026-08-02")
        #expect(id.hasPrefix(StreakAboutToBreakScheduler.identifierPrefix))
    }

    @Test("should remind only if not posted today AND has a streak")
    func shouldRemindWhenStreakAtRisk() {
        #expect(StreakAboutToBreakScheduler.shouldRemindToday(hasPostedToday: false, currentStreak: 5))
        #expect(StreakAboutToBreakScheduler.shouldRemindToday(hasPostedToday: false, currentStreak: 1))
    }

    @Test("should not remind if already posted today")
    func shouldNotRemindWhenPostedToday() {
        #expect(!StreakAboutToBreakScheduler.shouldRemindToday(hasPostedToday: true, currentStreak: 5))
        #expect(!StreakAboutToBreakScheduler.shouldRemindToday(hasPostedToday: true, currentStreak: 1))
    }

    @Test("should not remind if streak is zero")
    func shouldNotRemindWhenNoStreak() {
        #expect(!StreakAboutToBreakScheduler.shouldRemindToday(hasPostedToday: false, currentStreak: 0))
    }

    @Test("should not remind if posted and no streak")
    func shouldNotRemindWhenPostedAndNoStreak() {
        #expect(!StreakAboutToBreakScheduler.shouldRemindToday(hasPostedToday: true, currentStreak: 0))
    }
}

import Foundation
import Testing
@testable import SkyGrid

@Suite("Buddy streak display policy")
struct BuddyStreakDisplayPolicyTests {
    private let today = LocalDate(year: 2026, month: 9, day: 5)

    @Test("shows a fresh streak today with singular copy")
    func showsToday() {
        #expect(BuddyStreakDisplayPolicy.display(
            current: 1,
            lastMutualDate: today,
            today: today,
            buddyName: "Ren"
        ) == .init(text: "Together 1 day", accessibilityLabel: "1 consecutive morning with Ren"))
    }

    @Test("shows a fresh streak from yesterday")
    func showsYesterday() {
        #expect(BuddyStreakDisplayPolicy.display(
            current: 12,
            lastMutualDate: today.adding(days: -1),
            today: today,
            buddyName: "Ren"
        ) == .init(text: "Together 12 days", accessibilityLabel: "12 consecutive mornings with Ren"))
    }

    @Test("stays silent for absent, stale, or invalid streaks")
    func hidesUnsafeOrStaleValues() {
        #expect(BuddyStreakDisplayPolicy.display(current: nil, lastMutualDate: today, today: today, buddyName: "Ren") == nil)
        #expect(BuddyStreakDisplayPolicy.display(current: 3, lastMutualDate: today.adding(days: -2), today: today, buddyName: "Ren") == nil)
        #expect(BuddyStreakDisplayPolicy.display(current: 0, lastMutualDate: today, today: today, buddyName: "Ren") == nil)
    }

    @Test("uses the viewer's supplied local day across a timezone boundary")
    func respectsSuppliedViewerDay() {
        let viewerToday = LocalDate(year: 2026, month: 1, day: 1)
        #expect(BuddyStreakDisplayPolicy.display(
            current: 2,
            lastMutualDate: LocalDate(year: 2025, month: 12, day: 31),
            today: viewerToday,
            buddyName: "Mira"
        )?.text == "Together 2 days")
    }
}

import Testing
@testable import SkyGrid

@Suite("RewardRevealPolicy")
struct RewardRevealPolicyTests {
    private let captureDate = LocalDate(year: 2026, month: 9, day: 6)

    @Test("accepts only the matching day's server-authoritative unlocked count")
    func acceptsMatchingReading() {
        let reading = RevealReading(
            localDate: captureDate,
            mutuallyUnlockedBuddyCount: 2,
            acceptedBuddyCount: 3
        )

        #expect(RewardRevealPolicy.verifiedUnlockedCount(for: captureDate, reading: reading) == 2)
    }

    @Test("does not turn a previous day's reading into a reveal")
    func rejectsStaleReading() {
        let yesterday = captureDate.adding(days: -1)
        let reading = RevealReading(
            localDate: yesterday,
            mutuallyUnlockedBuddyCount: 3,
            acceptedBuddyCount: 3
        )

        #expect(RewardRevealPolicy.verifiedUnlockedCount(for: captureDate, reading: reading) == 0)
        #expect(RewardRevealPolicy.verifiedUnlockedCount(for: captureDate, reading: nil) == 0)
    }
}

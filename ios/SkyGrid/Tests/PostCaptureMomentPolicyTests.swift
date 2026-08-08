import Foundation
import Testing
@testable import SkyGrid

@Suite("PostCaptureMomentPolicy")
struct PostCaptureMomentPolicyTests {
    private let today = LocalDate(year: 2026, month: 8, day: 8)
    private let armedAt = Date(timeIntervalSince1970: 1_000_000)

    private func arming(
        paywall: Bool,
        count: Int = 1,
        localDate: LocalDate? = nil
    ) -> PostCaptureArming {
        PostCaptureArming(
            localDate: localDate ?? today,
            completedCaptureCount: count,
            didPresentPaywall: paywall,
            armedAt: armedAt
        )
    }

    private func post(on localDate: LocalDate? = nil) -> SkyPost {
        SkyPost(
            ownerUid: "u1",
            localDate: localDate ?? today,
            capturedAt: armedAt,
            uploadedAt: armedAt,
            imagePath: "users/u1/2026-08-08.jpg",
            thumbPath: "users/u1/2026-08-08-thumb.jpg",
            skyColor: SkyColor(uncheckedHex: "#88AACC"),
            minutesFromGoal: -5,
            reactions: [:]
        )
    }

    private func observed(streak: Int, postedToday: Bool = true, hasPost: Bool = true, on localDate: LocalDate? = nil) -> StreakReading {
        .observed(
            localDate: localDate ?? today,
            summary: StreakSummary(currentStreak: streak, hasPostedToday: postedToday),
            post: hasPost ? post(on: localDate) : nil
        )
    }

    private func decide(
        _ arming: PostCaptureArming,
        _ reading: StreakReading?,
        lastCelebrated: Int = 0,
        hasRequestedAppReview: Bool = false,
        elapsed: TimeInterval = 1
    ) -> PostCaptureMoment {
        PostCaptureMomentPolicy.decide(
            arming: arming,
            reading: reading,
            lastCelebratedMilestone: lastCelebrated,
            hasRequestedAppReview: hasRequestedAppReview,
            now: armedAt.addingTimeInterval(elapsed)
        )
    }

    // MARK: - Paywall precedence (the invariant that must never regress)

    @Test("the paywall wins before anything else is even considered")
    func paywallWinsWithNoReading() {
        #expect(decide(arming(paywall: true), nil) == .paywall)
    }

    @Test("the paywall still wins against a perfect milestone reading")
    func paywallOutranksMilestone() {
        let moment = decide(arming(paywall: true, count: 7), observed(streak: 7))
        #expect(moment == .paywall)
    }

    // MARK: - Ordering: the review may not jump ahead of an undecided milestone

    /// The regression test for the ordering change. Before this policy existed the
    /// review fired the instant the paywall declined; now it must wait until the
    /// milestone question is actually answerable.
    @Test("a declined paywall with no streak reading yet holds, it does not ask for a review")
    func awaitsStreakBeforeReview() {
        #expect(decide(arming(paywall: false, count: 7), nil) == .awaitingStreak)
    }

    @Test("a reading for a different day does not resolve this capture")
    func readingForAnotherDayHolds() {
        let other = today.adding(days: -1)
        #expect(decide(arming(paywall: false), observed(streak: 7, on: other)) == .awaitingStreak)
    }

    // MARK: - Milestone

    @Test("an exact milestone on the armed day fires")
    func milestoneFires() {
        #expect(decide(arming(paywall: false, count: 7), observed(streak: 7), lastCelebrated: 1) == .milestone(StreakMilestone(streak: 7)))
    }

    @Test("day one fires the milestone and never the review")
    func dayOneFiresMilestone() {
        #expect(decide(arming(paywall: false, count: 1), observed(streak: 1)) == .milestone(StreakMilestone(streak: 1)))
    }

    @Test("an already-celebrated milestone falls through to the review")
    func celebratedMilestoneFallsThroughToReview() {
        #expect(decide(arming(paywall: false, count: 7), observed(streak: 7), lastCelebrated: 7) == .reviewPrompt)
    }

    @Test("the same inputs cannot fire a second milestone once the guard advanced")
    func milestoneIsIdempotent() {
        let armed = arming(paywall: false, count: 7)
        #expect(decide(armed, observed(streak: 7), lastCelebrated: 0) == .milestone(StreakMilestone(streak: 7)))
        #expect(decide(armed, observed(streak: 7), lastCelebrated: 7) == .reviewPrompt)
    }

    // MARK: - Never celebrate from an untrustworthy reading

    @Test("a failed history read never produces a milestone")
    func unavailableNeverCelebrates() {
        #expect(decide(arming(paywall: false, count: 7), .unavailable(localDate: today), lastCelebrated: 0) == .reviewPrompt)
        #expect(decide(arming(paywall: false, count: 1), .unavailable(localDate: today), lastCelebrated: 0) == PostCaptureMoment.none)
    }

    /// `StreakCalculator` keeps yesterday's count alive until the day is over, so a
    /// reading taken before today's post lands reports a streak that is not about
    /// today. Celebrating it would print a number the user has not yet earned.
    @Test("a grace-mode reading taken before today's post lands is not a milestone")
    func graceModeReadingHolds() {
        #expect(decide(arming(paywall: false), observed(streak: 7, postedToday: false)) == .awaitingStreak)
    }

    @Test("a reading with no post for the day holds, because no truthful card exists")
    func missingPostHolds() {
        #expect(decide(arming(paywall: false), observed(streak: 7, hasPost: false)) == .awaitingStreak)
    }

    // MARK: - Staleness

    @Test("an arming that outlived its window resolves to nothing, milestone or not")
    func staleArmingExpires() {
        let elapsed = PostCaptureMomentPolicy.armingLifetime + 1
        #expect(decide(arming(paywall: false, count: 7), observed(streak: 7), elapsed: elapsed) == PostCaptureMoment.none)
    }

    // MARK: - Review gating is delegated, not duplicated

    @Test("the review keeps AppReviewPromptPolicy's own gate")
    func reviewGateIsDelegated() {
        #expect(decide(arming(paywall: false, count: 6), observed(streak: 6)) == PostCaptureMoment.none)
        #expect(decide(arming(paywall: false, count: 7), observed(streak: 8)) == .reviewPrompt)
        #expect(decide(arming(paywall: false, count: 7), observed(streak: 8), hasRequestedAppReview: true) == PostCaptureMoment.none)
    }
}

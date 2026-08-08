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
            isPaywallEligible: paywall,
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

    // MARK: - Milestone outranks the paywall (owner's decision, 2026-08-08)

    /// The core of the reversal: a milestone day takes the capture, and the paywall
    /// is expected to reappear on the next one via its own "N captures or N days"
    /// gate — which works precisely because nothing is recorded as presented here.
    @Test("a milestone day takes the capture even when the paywall is eligible")
    func milestoneOutranksEligiblePaywall() {
        let moment = decide(arming(paywall: true, count: 7), observed(streak: 7))
        #expect(moment == .milestone(StreakMilestone(streak: 7)))
    }

    @Test("an eligible paywall still fires on an ordinary morning")
    func paywallFiresWithoutAMilestone() {
        #expect(decide(arming(paywall: true, count: 8), observed(streak: 8)) == .paywall)
    }

    /// An eligible paywall must not jump ahead while the milestone question is still
    /// unanswerable — that would reinstate the behaviour this change removed.
    @Test("an eligible paywall waits for the streak rather than pre-empting a milestone")
    func eligiblePaywallWaitsForTheStreak() {
        #expect(decide(arming(paywall: true, count: 7), nil) == .awaitingStreak)
    }

    // MARK: - Ordering: the review may not jump ahead of an undecided milestone

    /// Before this policy existed the review fired the instant the paywall declined;
    /// now it must wait until the milestone question is actually answerable.
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

    /// A read that failed cannot prove a milestone, so the paywall keeps its turn
    /// rather than being deferred on a day nobody can show was special.
    @Test("a failed history read does not defer an eligible paywall")
    func unavailableDoesNotDeferThePaywall() {
        #expect(decide(arming(paywall: true, count: 7), .unavailable(localDate: today)) == .paywall)
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

    @Test("an arming that outlived its window no longer celebrates, milestone or not")
    func staleArmingNeverCelebrates() {
        let elapsed = PostCaptureMomentPolicy.armingLifetime + 1
        #expect(decide(arming(paywall: false, count: 1), observed(streak: 7), elapsed: elapsed) == PostCaptureMoment.none)
    }

    /// The backstop that keeps a missing streak from silently costing the paywall its
    /// turn. Without this, an unattached history listener would strand the arming.
    @Test("an expired arming still lets an eligible paywall through")
    func staleArmingStillPresentsThePaywall() {
        let elapsed = PostCaptureMomentPolicy.armingLifetime + 1
        #expect(decide(arming(paywall: true, count: 7), nil, elapsed: elapsed) == .paywall)
        #expect(decide(arming(paywall: true, count: 7), observed(streak: 7), elapsed: elapsed) == .paywall)
    }

    @Test("an expired arming with no paywall due falls back to the review gate")
    func staleArmingFallsBackToReview() {
        let elapsed = PostCaptureMomentPolicy.armingLifetime + 1
        #expect(decide(arming(paywall: false, count: 7), nil, elapsed: elapsed) == .reviewPrompt)
    }

    // MARK: - Review gating is delegated, not duplicated

    @Test("the review keeps AppReviewPromptPolicy's own gate")
    func reviewGateIsDelegated() {
        #expect(decide(arming(paywall: false, count: 6), observed(streak: 6)) == PostCaptureMoment.none)
        #expect(decide(arming(paywall: false, count: 7), observed(streak: 8)) == .reviewPrompt)
        #expect(decide(arming(paywall: false, count: 7), observed(streak: 8), hasRequestedAppReview: true) == PostCaptureMoment.none)
    }
}

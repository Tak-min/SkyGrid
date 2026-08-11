import Foundation

/// Everything known at the instant a capture completed, frozen so the decision can be
/// re-run later — when the streak finally arrives — without re-deriving anything.
struct PostCaptureArming: Equatable, Sendable {
    let localDate: LocalDate
    let completedCaptureCount: Int
    let armedAt: Date
}

enum PostCaptureMoment: Equatable {
    /// The streak that would answer the milestone question has not arrived yet. The
    /// caller must stay armed and re-ask, and must **not** fall through to anything
    /// lower — that is what lets a milestone outrank an eligible paywall.
    case awaitingStreak
    case milestone(StreakMilestone)
    /// Present the first-unlock paywall now. Eligibility is decided by
    /// `FirstUnlockPaywallPolicy` and passed in fresh at every re-ask (see
    /// `decide(isPaywallEligible:)`) — unlike the retired capture-count reminder,
    /// eligibility here can change *after* the capture, when a buddy who wasn't
    /// mutually unlocked yet posts hours later.
    case paywall
    case reviewPrompt
    case none
}

/// Arbitrates what — if anything — a completed capture earns, in the order
/// **milestone > paywall > review prompt**.
///
/// A pure function so the whole ordering guarantee is testable without a simulator,
/// which matters because Firebase is unreachable from the simulator in this project
/// (App Check) and the real path can't be exercised there.
///
/// **The milestone outranking the paywall is a deliberate reversal** (2026-08-08,
/// product owner's decision). It replaces the earlier rule, under which a milestone
/// landing on a paywall capture was dropped forever. The paywall is now *deferred*
/// instead: it is simply not presented and, crucially, **not recorded as presented**
/// (`RootView.recordAutomaticPaywallPresentationIfNeeded` only writes
/// `LocalDefaults.unlockPaywallPresentedAt` on the branch that actually shows it), so
/// the very next re-ask — driven by `RevealSignal` or the milestone's own dismissal —
/// offers it again. Deferral therefore needs no new stored state and cannot
/// permanently suppress the paywall — there is nothing persisted that could get stuck.
///
/// Unlike the retired capture-count reminder, this policy's eligibility input is not
/// frozen at capture-confirm time: `isPaywallEligible` is passed fresh at every call,
/// because a mutual unlock can land asynchronously, well after the capture that armed
/// this decision. Nothing here decides *whether* the paywall is due, only whether
/// today is the day it appears once `FirstUnlockPaywallPolicy` says it's eligible.
enum PostCaptureMomentPolicy {
    /// How long to wait for the streak before giving up on the milestone question.
    ///
    /// Normally irrelevant: Firestore's local write echo means the history listener
    /// republishes within moments of the capture, and an offline listener publishes
    /// `.unavailable` just as promptly. This only covers the pathological case where
    /// no reading arrives at all (e.g. the listener was never attached), and it exists
    /// so a missing streak cannot silently swallow an eligible paywall.
    static let armingLifetime: TimeInterval = 10

    static func decide(
        arming: PostCaptureArming,
        isPaywallEligible: Bool,
        reading: StreakReading?,
        lastCelebratedMilestone: Int,
        hasRequestedAppReview: Bool,
        now: Date
    ) -> PostCaptureMoment {
        // 1. Gave up waiting for the streak. Never celebrate on no evidence, but do
        //    not let a missing reading cost the paywall its turn.
        if now.timeIntervalSince(arming.armedAt) > armingLifetime {
            return isPaywallEligible ? .paywall : reviewOrNothing(arming, hasRequestedAppReview)
        }

        // 2. Nothing to judge yet, or a snapshot about a different day. Hold —
        //    including when the paywall is eligible, since that is precisely the
        //    case where a milestone would outrank it.
        guard let reading, reading.localDate == arming.localDate else { return .awaitingStreak }

        // 3. Only a reading that actually establishes today's streak may celebrate.
        if case .observed(_, let summary, let post) = reading {
            // `StreakCalculator` keeps yesterday's count alive until the day is over,
            // so a pre-post reading describes yesterday, not the capture just made.
            guard summary.hasPostedToday, post != nil else { return .awaitingStreak }
            if let milestone = StreakMilestone.reached(
                streak: summary.currentStreak,
                lastCelebrated: lastCelebratedMilestone
            ) {
                // The paywall defers to the next capture by simply not happening here.
                return .milestone(milestone)
            }
        }

        // 4. No milestone. `.unavailable` also lands here — a failed read may never
        //    assert a milestone, but it says nothing about the paywall or the review.
        if isPaywallEligible { return .paywall }
        return reviewOrNothing(arming, hasRequestedAppReview)
    }

    private static func reviewOrNothing(
        _ arming: PostCaptureArming,
        _ hasRequestedAppReview: Bool
    ) -> PostCaptureMoment {
        AppReviewPromptPolicy.shouldRequest(
            completedCaptureCount: arming.completedCaptureCount,
            hasRequestedBefore: hasRequestedAppReview
        ) ? .reviewPrompt : .none
    }
}

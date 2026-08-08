import Foundation

/// Everything known at the instant a capture completed, frozen so the decision can be
/// re-run later — when the streak finally arrives — without re-deriving anything.
struct PostCaptureArming: Equatable, Sendable {
    let localDate: LocalDate
    let completedCaptureCount: Int
    /// The verdict `AutomaticPaywallPresentationPolicy` **already** returned. Carried
    /// as a plain `Bool` on purpose: this policy must be structurally incapable of
    /// re-deciding the paywall, so it is never given the inputs to do so.
    ///
    /// In production this is always `false`, because `RootView` clears the arming
    /// outright when the paywall claims a capture — precedence is enforced by the
    /// arming not existing, which is stronger than a flag. The field and its branch
    /// are kept so that "the paywall outranks everything" is stated and *tested*
    /// here rather than living only as an invisible property of the call site.
    let didPresentPaywall: Bool
    let armedAt: Date
}

enum PostCaptureMoment: Equatable {
    /// Owned entirely by the existing `pendingAutomaticPaywall` path — this policy
    /// only reports that the paywall took the capture.
    case paywall
    /// The streak that would answer the milestone question has not arrived yet. The
    /// caller must stay armed and re-ask, and must **not** fall through to the review.
    case awaitingStreak
    case milestone(StreakMilestone)
    case reviewPrompt
    case none
}

/// Arbitrates what — if anything — a completed capture earns, in the fixed order
/// **paywall > milestone > review prompt**.
///
/// A pure function so the whole ordering guarantee is testable without a simulator,
/// which matters because Firebase is unreachable from the simulator in this project
/// (App Check) and the real path can't be exercised there.
///
/// The paywall's own predicate is deliberately absent: `AutomaticPaywallPresentationPolicy`
/// runs at capture-confirm time and its result is passed in. Nothing here can change
/// when the paywall fires.
enum PostCaptureMomentPolicy {
    /// A celebration has to feel caused by the capture that earned it. Past this,
    /// the user has moved on and a full-screen takeover would read as a glitch, so a
    /// late-arriving streak is dropped rather than presented.
    static let armingLifetime: TimeInterval = 10

    static func decide(
        arming: PostCaptureArming,
        reading: StreakReading?,
        lastCelebratedMilestone: Int,
        hasRequestedAppReview: Bool,
        now: Date
    ) -> PostCaptureMoment {
        // 1. Paywall precedence, unconditional and first.
        if arming.didPresentPaywall { return .paywall }

        // 2. Too late to read as a consequence of the capture.
        if now.timeIntervalSince(arming.armedAt) > armingLifetime { return .none }

        // 3-4. Nothing to judge yet, or a snapshot about a different day.
        guard let reading, reading.localDate == arming.localDate else { return .awaitingStreak }

        // 5-7. Only a reading that actually establishes today's streak may celebrate.
        if case .observed(_, let summary, let post) = reading {
            // `StreakCalculator` keeps yesterday's count alive until the day is over,
            // so a pre-post reading describes yesterday, not the capture just made.
            guard summary.hasPostedToday, post != nil else { return .awaitingStreak }
            if let milestone = StreakMilestone.reached(
                streak: summary.currentStreak,
                lastCelebrated: lastCelebratedMilestone
            ) {
                return .milestone(milestone)
            }
        }

        // 8. `.unavailable` lands here too: no milestone may ever be asserted from a
        // failed read, but the review ask does not depend on the streak at all.
        guard AppReviewPromptPolicy.shouldRequest(
            completedCaptureCount: arming.completedCaptureCount,
            hasRequestedBefore: hasRequestedAppReview
        ) else { return .none }
        return .reviewPrompt
    }
}

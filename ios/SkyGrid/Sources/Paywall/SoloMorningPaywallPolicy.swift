import Foundation

/// Controls the automatic paywall reminder for someone with **zero accepted buddies**.
/// `FirstUnlockPaywallPolicy` already owns the automatic reminder for anyone paired —
/// this policy exists because that path structurally never fires for a person with no
/// buddy relationship to unlock in the first place, which used to mean no automatic
/// reminder ever reached them.
///
/// Unlike `FirstUnlockPaywallPolicy` (one-shot), this is a **cadenced** reminder —
/// closer in spirit to the retired `AutomaticPaywallPresentationPolicy` — because a
/// solo person has no later structural event (a buddy's mutual unlock) to key a
/// second offer off. The cadence is deliberately aggressive (owner's decision,
/// 2026-08-13): every `capturesBetweenPrompts` captures *or* `daysBetweenPrompts`
/// calendar days, whichever comes first, snoozing only after repeated dismissals.
enum SoloMorningPaywallPolicy {
    enum Verdict: Equatable {
        /// Present the paywall now.
        case present
        /// A terminal no for this call: subscribed, has a buddy, snoozed, or the
        /// cadence has not yet elapsed.
        case notEligible
        /// The friendship snapshot has not resolved yet (`RevealReading` is `nil`, is
        /// for a different day, or its `acceptedBuddyCount` is `nil`). This is
        /// deliberately distinct from `.notEligible`: a caller must re-ask once a
        /// fresh `RevealReading` arrives rather than concluding "not solo" from an
        /// absence of evidence.
        case undetermined
    }

    static let minimumCompletedCaptures = 1
    static let capturesBetweenPrompts = 2
    static let daysBetweenPrompts = 2
    static let dismissalsBeforeSnooze = 2
    static let snoozeInterval: TimeInterval = 4 * 24 * 60 * 60
    static let dismissalsBeforeLongSnooze = 4
    static let longSnoozeInterval: TimeInterval = 10 * 24 * 60 * 60

    static func evaluate(
        entitlementStatus: EntitlementStatus,
        reading: RevealReading?,
        completedCaptureCount: Int,
        captureLocalDate: LocalDate,
        lastPromptedCaptureCount: Int?,
        lastPromptedLocalDate: LocalDate?,
        snoozedUntil: Date?,
        now: Date
    ) -> Verdict {
        guard entitlementStatus != .subscribed else { return .notEligible }
        guard completedCaptureCount >= minimumCompletedCaptures else { return .notEligible }

        guard let reading, reading.localDate == captureLocalDate else { return .undetermined }
        guard let acceptedBuddyCount = reading.acceptedBuddyCount else { return .undetermined }
        guard acceptedBuddyCount == 0 else { return .notEligible }

        if let snoozedUntil, snoozedUntil > now { return .notEligible }

        guard let lastPromptedCaptureCount, let lastPromptedLocalDate else { return .present }

        let hasCapturedEnough = completedCaptureCount - lastPromptedCaptureCount >= capturesBetweenPrompts
        let hasWaitedLongEnough = lastPromptedLocalDate.daysUntil(captureLocalDate) >= daysBetweenPrompts
        return (hasCapturedEnough || hasWaitedLongEnough) ? .present : .notEligible
    }

    /// `nil` means "no snooze" — the next eligible capture may prompt immediately.
    static func snoozeUntil(afterConsecutiveDismissals count: Int, now: Date) -> Date? {
        switch count {
        case ..<dismissalsBeforeSnooze:
            return nil
        case dismissalsBeforeSnooze..<dismissalsBeforeLongSnooze:
            return now.addingTimeInterval(snoozeInterval)
        default:
            return now.addingTimeInterval(longSnoozeInterval)
        }
    }
}

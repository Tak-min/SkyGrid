import Foundation

/// Controls the one and only *automatic* paywall presentation: the moment a person's
/// sky is first mutually revealed with a buddy. Replaces
/// `AutomaticPaywallPresentationPolicy` (retired alongside the capture-count reminder
/// it governed) now that a buddy relationship exists to key the reminder off instead.
///
/// The owner's decision (recorded 2026-08-10, restated in
/// `dev-notes/share-card-qr-removal-and-invite-blueprint_2026-08-11.md` §4-2): the
/// automatic paywall fires immediately after the first mutual unlock, not at a later
/// capture milestone — `minimumCompletedCaptures = 1` reflects that, not a coincidence
/// with `StreakMilestone.thresholds` containing `1`.
///
/// One-shot, not cadenced: once `hasPresentedUnlockPaywall` is `true` there is no
/// second automatic offer, unlike the retired policy's repeating snooze/cadence.
/// Manual plan, Settings, and locked-archive entry points are untouched by this policy
/// and remain available whenever a person asks for them.
enum FirstUnlockPaywallPolicy {
    static let minimumCompletedCaptures = 1

    static func shouldPresent(
        entitlementStatus: EntitlementStatus,
        reading: RevealReading?,
        completedCaptureCount: Int,
        hasPresentedUnlockPaywall: Bool
    ) -> Bool {
        // A stale or unavailable entitlement check must be re-verified before an
        // automatic reminder offers a new purchase — PaywallView performs one fresh
        // verification before it exposes purchase controls in the unresolved case,
        // mirroring the retired policy's same `.unknown`-passes-through behavior.
        guard entitlementStatus != .subscribed,
              !hasPresentedUnlockPaywall,
              completedCaptureCount >= minimumCompletedCaptures,
              let reading, reading.mutuallyUnlockedBuddyCount > 0
        else { return false }
        return true
    }
}

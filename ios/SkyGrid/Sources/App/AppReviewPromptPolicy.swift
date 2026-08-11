import Foundation

/// Governs whether a completed-capture moment is also a good moment to ask for
/// an App Store rating. Deliberately separate from `FirstUnlockPaywallPolicy`
/// so the two automatic prompts never compete for the same capture event — the
/// caller only asks this policy when the paywall has already decided not to show.
/// StoreKit's own review-request throttle is silent and per-installation, so this
/// only needs to pick one deliberate first moment; it does not attempt to model
/// repeat asks.
enum AppReviewPromptPolicy {
    /// A week of mornings is enough to have formed an opinion, and lands after the
    /// paywall's own floor (`FirstUnlockPaywallPolicy.minimumCompletedCaptures`)
    /// so the two prompts are never eligible on the exact same capture.
    static let triggerCaptureCount = 7

    static func shouldRequest(completedCaptureCount: Int, hasRequestedBefore: Bool) -> Bool {
        !hasRequestedBefore && completedCaptureCount >= triggerCaptureCount
    }
}

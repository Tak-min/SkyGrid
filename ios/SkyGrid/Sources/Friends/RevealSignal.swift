import Foundation
import Observation

/// One snapshot of the buddy strip, as computed by the *only* thing that resolves it
/// (`TodayViewModel.refreshBuddies`).
struct RevealReading: Equatable, Sendable {
    let localDate: LocalDate
    /// Buddies whose sky is visible right now. `BuddyRevealState.posted` is only set
    /// after `firestore.rules` permitted the read, and it permits it only when
    /// `activeBuddy(uid) && hasPostedFor(localDate)` — so any non-zero value here is
    /// server-verified proof of mutual unlock, not a client inference. Deliberately no
    /// `.unavailable` case unlike `StreakReading`: a failed buddy read already degrades
    /// to a sealed/not-posted state and contributes 0 here, and nothing downstream ever
    /// acts on "the read failed" — only on "at least one buddy is unlocked" — so there
    /// is no failed-read state that could be mistaken for an unlock.
    let mutuallyUnlockedBuddyCount: Int
    /// The count of accepted buddy relationships, independent of today's reveal state.
    /// `nil` means the friendship snapshot has never landed yet — genuinely unknown,
    /// not zero. `SoloMorningPaywallPolicy` depends on this distinction: treating an
    /// unresolved read as "zero buddies" would misclassify a paired person as solo
    /// during the window before their friendship listener first fires.
    let acceptedBuddyCount: Int?
    /// The same privacy-gated states displayed in Today's buddy strip. Keeping the
    /// already-resolved values here lets the Buddies tab describe a relationship
    /// without issuing a second post read or attempting to reproduce the gate.
    let buddyStatuses: [TodayViewModel.BuddyStatus]

    init(
        localDate: LocalDate,
        mutuallyUnlockedBuddyCount: Int,
        acceptedBuddyCount: Int?,
        buddyStatuses: [TodayViewModel.BuddyStatus] = []
    ) {
        self.localDate = localDate
        self.mutuallyUnlockedBuddyCount = mutuallyUnlockedBuddyCount
        self.acceptedBuddyCount = acceptedBuddyCount
        self.buddyStatuses = buddyStatuses
    }
}

/// A one-way channel from the buddy strip's single producer (`TodayViewModel`) up to
/// `RootView`, mirroring `StreakSignal`. `RootView` owns post-capture moment
/// arbitration and the first-unlock paywall but has no reference to the view model
/// (`TodayView` captures it as `@State`).
@MainActor
@Observable
final class RevealSignal {
    private(set) var reading: RevealReading?

    /// No-ops on an equal value — the buddy listener can re-emit the same snapshot,
    /// and a silent write would re-fire every `onChange` observer for no state change.
    func record(_ reading: RevealReading) {
        guard self.reading != reading else { return }
        self.reading = reading
    }
}

import FirebaseAnalytics
import FirebaseCore

/// Measures the mutual-reveal funnel's terminal event: a buddy strip going from
/// zero unlocked buddies to at least one. This is the single target metric the
/// 2026-09-04 stickiness loop is optimizing for pre-promotion (see
/// `dev-notes/virality-stickiness-assessment_2026-09-04.md`) — deliberately no
/// buddy uid, handle, or photo in the payload, only the transition itself.
enum BuddyAnalytics {
    enum Event: String {
        case mutualRevealUnlocked = "skygrid_mutual_reveal_unlocked"
    }

    static func record(_ event: Event, unlockedBuddyCount: Int) {
        // UI-audit launches intentionally skip Firebase configuration. Do not
        // turn local visual checks into a network dependency or a fake event.
        guard FirebaseApp.app() != nil else { return }

        Analytics.logEvent(event.rawValue, parameters: [
            "unlocked_buddy_count": unlockedBuddyCount
        ])
    }
}

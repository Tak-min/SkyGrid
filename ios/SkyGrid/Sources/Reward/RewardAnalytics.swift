import FirebaseAnalytics
import FirebaseCore

/// Measures the daily reward sequence's start and finish. Deliberately no photo,
/// uid, or sky color in the payload — mirrors `CaptureAnalytics`'s privacy posture.
/// `reducedMotion` distinguishes the accessibility-equivalent path from the normal
/// spatial sequence on both events, which is enough to answer "started / completed /
/// reduced-motion" without inventing a third event name for a variant of the same
/// two moments.
enum RewardAnalytics {
    enum Event: String {
        case rewardStarted = "skygrid_reward_started"
        case rewardCompleted = "skygrid_reward_completed"
    }

    static func record(_ event: Event, reducedMotion: Bool) {
        // UI-audit launches intentionally skip Firebase configuration. Do not
        // turn local visual checks into a network dependency or a fake event.
        guard FirebaseApp.app() != nil else { return }

        Analytics.logEvent(event.rawValue, parameters: [
            "reduced_motion": reducedMotion
        ])
    }
}

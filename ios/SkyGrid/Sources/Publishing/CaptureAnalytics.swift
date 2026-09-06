import FirebaseAnalytics
import FirebaseCore

/// Measures the capture funnel's terminal event: `PostPublisher.publish` returning
/// without throwing, i.e. the local post and its upload-outbox row are both durably
/// written. Deliberately no image, uid, or sky color in the payload — only how close
/// the capture landed to the user's wake goal, which is the signal the
/// stickiness/virality assessment needs to reason about habit formation.
enum CaptureAnalytics {
    enum Event: String {
        case captureCompleted = "skygrid_capture_completed"
    }

    static func record(_ event: Event, minutesFromGoal: Int) {
        // UI-audit launches intentionally skip Firebase configuration. Do not
        // turn local visual checks into a network dependency or a fake event.
        guard FirebaseApp.app() != nil else { return }

        Analytics.logEvent(event.rawValue, parameters: [
            "minutes_from_goal": minutesFromGoal,
            "schema_version": 1
        ])
        if let duration = FirstCaptureJourney.standard.complete() {
            Analytics.logEvent("skygrid_first_capture_duration", parameters: [
                "duration_seconds": duration,
                "schema_version": 1,
                "experience_variant": "moku_companion"
            ])
        }
    }
}

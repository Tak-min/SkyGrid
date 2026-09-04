import FirebaseAnalytics
import FirebaseCore

/// Anonymous funnel telemetry for deciding whether an onboarding question earns
/// its place. It intentionally carries neither a UID nor any selected answer:
/// answers such as wake time are product preferences, not needed to measure step
/// drop-off, and must not become analytics payloads by accident.
enum OnboardingAnalytics {
    enum Event: String {
        case stepViewed = "skygrid_onboarding_step_viewed"
        case stepAdvanced = "skygrid_onboarding_step_advanced"
        case stepBacked = "skygrid_onboarding_step_backed"
        case stepSkipped = "skygrid_onboarding_step_skipped"
        case completed = "skygrid_onboarding_completed"
    }

    static func record(_ event: Event, step: OnboardingStep) {
        // The UI-audit harness deliberately has no Firebase app. Rendering a
        // screen must remain offline and must never manufacture analytics data.
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent(event.rawValue, parameters: [
            "step": step.rawValue,
            "schema_version": 1,
        ])
    }
}

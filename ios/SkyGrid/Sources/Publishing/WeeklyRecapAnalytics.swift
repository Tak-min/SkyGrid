import FirebaseAnalytics
import FirebaseCore

/// Measures the explicit recap-open -> share-sheet-open funnel. `ShareSheet` has no
/// completion callback, so `shared` records intent, not a claim that a recipient saw it.
enum WeeklyRecapAnalytics {
    enum Event: String {
        case opened = "skygrid_weekly_recap_opened"
        case shared = "skygrid_weekly_recap_shared"
    }

    static func record(_ event: Event) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent(event.rawValue, parameters: ["schema_version": 1])
    }
}

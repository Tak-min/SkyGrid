import FirebaseAnalytics
import FirebaseCore

/// Records intent to share the one-morning card. `ShareSheet` has no completion
/// callback, so this matches InviteAnalytics: a tap that opens the system sheet is
/// the observable event, not an assertion that an external recipient received it.
enum MorningShareAnalytics {
    enum Event: String {
        case shared = "skygrid_morning_shared"
    }

    enum Placement: String {
        case today
        case milestone
    }

    static func record(_ event: Event, placement: Placement) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent(event.rawValue, parameters: [
            "placement": placement.rawValue
        ])
    }
}

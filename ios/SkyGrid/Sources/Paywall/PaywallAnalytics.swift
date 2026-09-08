import FirebaseAnalytics
import FirebaseCore

/// The paywall funnel is deliberately measured without a user ID, photo, answer,
/// wake goal, price, or product identifier. RevenueCat remains the source of
/// truth for revenue; these events reveal where a voluntarily opened funnel
/// loses people so that we can improve the explanation, not target individuals.
enum PaywallAnalytics {
    enum Event: String {
        case presented = "skygrid_paywall_presented"
        case stepViewed = "skygrid_paywall_step_viewed"
        case valuePreviewCompleted = "skygrid_paywall_value_preview_completed"
        case planSelected = "skygrid_paywall_plan_selected"
        case purchaseStarted = "skygrid_paywall_purchase_started"
        case purchaseConfirmed = "skygrid_paywall_purchase_confirmed"
        case restoreStarted = "skygrid_paywall_restore_started"
        case restoreConfirmed = "skygrid_paywall_restore_confirmed"
        case dismissed = "skygrid_paywall_dismissed"
    }

    static func record(
        _ event: Event,
        entryPoint: PaywallEntryPoint,
        period: PurchasePeriod? = nil,
        dismissalReason: PaywallDismissalReason? = nil,
        step: PaywallStep? = nil
    ) {
        // UI-audit launches intentionally skip Firebase configuration. Do not
        // turn local visual checks into a network dependency or a fake event.
        guard FirebaseApp.app() != nil else { return }

        var parameters: [String: Any] = [
            "entry_point": entryPoint.analyticsName,
            "automatic": entryPoint.isAutomaticReminder ? 1 : 0,
            "schema_version": 1
        ]
        if let period {
            parameters["plan_period"] = period.analyticsName
        }
        if let dismissalReason {
            parameters["dismissal_reason"] = dismissalReason.analyticsName
        }
        if let step {
            parameters["step"] = step.rawValue
        }
        Analytics.logEvent(event.rawValue, parameters: parameters)
    }
}

private extension PurchasePeriod {
    var analyticsName: String {
        switch self {
        case .monthly: "monthly"
        case .annual: "annual"
        case .lifetime: "lifetime"
        case .unknown: "unknown"
        }
    }
}

private extension PaywallDismissalReason {
    var analyticsName: String {
        switch self {
        case .close: "close"
        case .continueWithFree: "free"
        case .interactiveDismissal: "interactive"
        }
    }
}

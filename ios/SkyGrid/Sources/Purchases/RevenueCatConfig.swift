import Foundation
import RevenueCat

/// Phase 2: only becomes active once the founder creates a real RevenueCat App and
/// drops the API key into `Config/Secrets.xcconfig` (see `Secrets.example.xcconfig`).
/// `ServiceFactory.hasFirebaseConfiguration` gates whether this ever gets called.
enum RevenueCatConfig {
    /// Must match the entitlement identifier configured in the RevenueCat dashboard.
    static let entitlementID = "premium"

    static var isConfigured: Bool {
        guard let key = rawAPIKey else { return false }
        return !key.isEmpty && !key.contains("YOUR_")
    }

    static func configureIfNeeded() {
        guard let key = rawAPIKey, isConfigured else { return }
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: key)
    }

    private static var rawAPIKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String
    }
}

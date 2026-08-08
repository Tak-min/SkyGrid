import Foundation
import RevenueCat

/// RevenueCat is configured only after Firebase has established the app's UID. This
/// makes the RevenueCat App User ID and Firebase UID identical, which is necessary
/// for authenticated webhook synchronisation on the server.
@MainActor
enum RevenueCatConfig {
    /// Must match the entitlement identifier configured in the RevenueCat dashboard.
    nonisolated static let entitlementID = "premium"

    static var isConfigured: Bool {
        guard let key = rawAPIKey else { return false }
        return !key.isEmpty && !key.contains("YOUR_")
    }

    private static var configuredUserID: String?

    static func configureOrIdentify(appUserID: String) async throws {
        guard let key = rawAPIKey, isConfigured else { return }
        guard !appUserID.isEmpty else { return }

        if let configuredUserID {
            guard configuredUserID != appUserID else { return }
            do {
                _ = try await Purchases.shared.logIn(appUserID)
                self.configuredUserID = appUserID
            } catch {
                throw RevenueCatConfigurationError.identitySwitchFailed
            }
            return
        }

        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: key, appUserID: appUserID)
        configuredUserID = appUserID
    }

    private static var rawAPIKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String
    }
}

enum RevenueCatConfigurationError: LocalizedError {
    /// Continuing with the prior RevenueCat App User ID could surface or attach a
    /// purchase to the wrong Sky Grid account. The app must stay fail-closed until
    /// RevenueCat confirms the identity switch.
    case identitySwitchFailed

    var errorDescription: String? {
        switch self {
        case .identitySwitchFailed:
            "Purchase access could not be verified for this account. Please try again."
        }
    }
}

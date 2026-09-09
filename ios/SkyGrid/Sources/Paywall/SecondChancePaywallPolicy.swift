import Foundation

/// The presentation rule is deliberately separate from Apple's introductory
/// price eligibility. This type decides whether the one-shot step may be tried;
/// RevenueCat remains the only authority on whether its product can be redeemed.
enum SecondChancePaywallPolicy {
    static let connectionTimeout: Duration = .seconds(7)

    static func shouldAttempt(
        entryPoint: PaywallEntryPoint,
        hasPresentedForAccount: Bool
    ) -> Bool {
        guard !hasPresentedForAccount else { return false }
        if case .onboarding = entryPoint { return true }
        return false
    }
}

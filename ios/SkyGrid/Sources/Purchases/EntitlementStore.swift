import Observation

/// A single observable entitlement source for screens that gate archive access.
/// It deliberately fails closed: a network failure never unlocks a paid feature.
@MainActor
@Observable
final class EntitlementStore {
    /// Until the first entitlement refresh completes, the app must not infer that a
    /// person is eligible for an automatic purchase reminder.
    private(set) var status: EntitlementStatus = .unknown
    private(set) var plan: SubscriptionPlan = .free
    private(set) var isRefreshing = false

    private let purchases: any PurchasesServicing

    init(purchases: any PurchasesServicing) {
        self.purchases = purchases
    }

    var isPro: Bool { status == .subscribed }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let summary = await purchases.entitlementSummary()
        status = summary.status
        plan = summary.plan
        isRefreshing = false
    }

    /// Lets Settings offer Restore without holding a `PaywallViewModel` of its own.
    /// Returns `true` once entitlement has been re-confirmed as subscribed.
    func restore() async -> Bool {
        guard let status = try? await purchases.restorePurchases() else { return false }
        await refresh()
        return status == .subscribed
    }
}

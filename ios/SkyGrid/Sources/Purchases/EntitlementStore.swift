import Observation

/// A single observable entitlement source for screens that gate archive access.
/// It deliberately fails closed: a network failure never unlocks a paid feature.
@MainActor
@Observable
final class EntitlementStore {
    private(set) var status: EntitlementStatus = .notSubscribed
    private(set) var isRefreshing = false

    private let purchases: any PurchasesServicing

    init(purchases: any PurchasesServicing) {
        self.purchases = purchases
    }

    var isPro: Bool { status == .subscribed }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        status = await purchases.entitlementStatus()
        isRefreshing = false
    }
}

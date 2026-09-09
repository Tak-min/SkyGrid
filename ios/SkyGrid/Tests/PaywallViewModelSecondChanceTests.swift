import Foundation
import Testing
@testable import SkyGrid

@MainActor
@Suite("Second-chance offer loading")
struct PaywallViewModelSecondChanceTests {
    @Test("a verified offer becomes ready with storefront labels intact")
    func verifiedOffer() async throws {
        let offer = SecondChanceOffer(
            product: PurchaseProduct(
                id: "monthly",
                title: "Monthly",
                priceLabel: "¥600",
                periodLabel: "Monthly",
                period: .monthly
            ),
            introductoryPriceLabel: "¥150",
            savingsLabel: "¥450",
            renewalPriceLabel: "¥600"
        )
        let model = PaywallViewModel(
            purchases: SecondChancePurchases(result: .success(offer))
        )

        model.loadSecondChanceOffer(timeout: .seconds(1))
        try await Task.sleep(for: .milliseconds(20))

        #expect(model.secondChanceState == .ready(offer))
    }

    @Test("an unresponsive storefront becomes disconnected at the supplied deadline")
    func timeout() async throws {
        let model = PaywallViewModel(
            purchases: SecondChancePurchases(result: .hang)
        )

        model.loadSecondChanceOffer(timeout: .milliseconds(10))
        try await Task.sleep(for: .milliseconds(30))

        #expect(model.secondChanceState == .disconnected)
    }
}

private struct SecondChancePurchases: PurchasesServicing {
    enum Result: Sendable {
        case success(SecondChanceOffer?)
        case hang
    }

    let result: Result

    func entitlementStatus() async -> EntitlementStatus { .notSubscribed }
    func fetchPaywall() async throws -> PaywallContent {
        PaywallContent(offeringID: "test", products: [])
    }
    func fetchSecondChanceOffer() async throws -> SecondChanceOffer? {
        switch result {
        case .success(let offer):
            return offer
        case .hang:
            try await Task.sleep(for: .seconds(60))
            return nil
        }
    }
    func purchase(product: PurchaseProduct) async throws -> EntitlementStatus { .notSubscribed }
    func restorePurchases() async throws -> EntitlementStatus { .notSubscribed }
}

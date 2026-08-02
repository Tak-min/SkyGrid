import Foundation
import Observation

/// Ported near-verbatim from Unhook's `PaywallViewModel.swift` — app-agnostic.
@MainActor
@Observable
final class PaywallViewModel {
    enum ViewState: Equatable {
        case loading
        case loaded(PaywallContent)
        case entitlementUnavailable
        case failed(String)
    }

    private(set) var state: ViewState = .loading
    private(set) var isPurchasing = false
    var errorMessage: String?

    private let purchases: any PurchasesServicing

    init(purchases: any PurchasesServicing) {
        self.purchases = purchases
    }

    /// For automatic reminders, re-check the entitlement immediately before
    /// loading products. This prevents a stale .unknown state from ever showing
    /// purchase controls to an existing subscriber.
    func load(verifyEntitlement: Bool) async -> EntitlementStatus? {
        state = .loading
        if verifyEntitlement {
            let status = await purchases.entitlementStatus()
            guard status == .notSubscribed else {
                state = status == .unknown ? .entitlementUnavailable : .failed("Your Pro access is already active.")
                return status
            }
        }
        do {
            state = .loaded(try await purchases.fetchPaywall())
        } catch {
            state = .failed(Self.message(for: error))
        }
        return nil
    }

    /// Returns `true` if entitlement was granted — caller should exit the funnel.
    func purchase(product: PurchaseProduct) async -> Bool {
        errorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if try await purchases.purchase(product: product) == .subscribed {
                return true
            }
            errorMessage = "Your purchase completed, but we could not confirm access. Try restoring purchases."
            return false
        } catch PurchaseError.userCancelled {
            return false
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    func restore() async -> Bool {
        errorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if try await purchases.restorePurchases() == .subscribed {
                return true
            }
            errorMessage = "No purchases were found to restore."
            return false
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    func refreshedEntitlementStatus() async -> EntitlementStatus {
        await purchases.entitlementStatus()
    }

    private static func message(for error: Error) -> String {
        switch error {
        case PurchaseError.configurationMissing:
            return "Subscriptions are not configured for this build."
        case PurchaseError.noOfferingAvailable, PurchaseError.productNotFound:
            return "Plans could not be loaded. Please try again in a moment."
        case PurchaseError.underlying(let message):
            return message
        default:
            return "Something went wrong. Please try again in a moment."
        }
    }
}

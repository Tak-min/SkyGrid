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

    enum SecondChanceState: Equatable {
        case idle
        case loading
        case ready(SecondChanceOffer)
        case unavailable
        case disconnected
    }

    private(set) var state: ViewState = .loading
    private(set) var isPurchasing = false
    private(set) var secondChanceState: SecondChanceState = .idle
    var errorMessage: String?

    private var secondChanceLoadTask: Task<Void, Never>?
    private var secondChanceTimeoutTask: Task<Void, Never>?

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
    func purchase(product: PurchaseProduct, usesSecondChanceOffer: Bool = false) async -> Bool {
        errorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let status = try await (
                usesSecondChanceOffer
                    ? purchases.purchaseSecondChance(product: product)
                    : purchases.purchase(product: product)
            )
            if status == .subscribed {
                return true
            }
            errorMessage = "Your purchase completed, but we could not confirm access. Try restoring purchases."
            return false
        } catch PurchaseError.userCancelled {
            return false
        } catch PurchaseError.paymentPending {
            errorMessage = "Your purchase is waiting for approval. Pro will unlock after Apple confirms it."
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

    func loadSecondChanceOffer(
        timeout: Duration = SecondChancePaywallPolicy.connectionTimeout
    ) {
        secondChanceLoadTask?.cancel()
        secondChanceTimeoutTask?.cancel()
        secondChanceState = .loading
        errorMessage = nil

        secondChanceLoadTask = Task { [purchases] in
            do {
                let offer = try await purchases.fetchSecondChanceOffer()
                guard !Task.isCancelled, secondChanceState == .loading else { return }
                secondChanceTimeoutTask?.cancel()
                secondChanceState = offer.map(SecondChanceState.ready) ?? .unavailable
            } catch {
                guard !Task.isCancelled, secondChanceState == .loading else { return }
                secondChanceTimeoutTask?.cancel()
                secondChanceState = .disconnected
            }
        }

        secondChanceTimeoutTask = Task {
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return
            }
            guard !Task.isCancelled, secondChanceState == .loading else { return }
            secondChanceLoadTask?.cancel()
            secondChanceState = .disconnected
        }
    }

    private static func message(for error: Error) -> String {
        switch error {
        case PurchaseError.configurationMissing:
            return "Subscriptions are not configured for this build."
        case PurchaseError.noOfferingAvailable, PurchaseError.productNotFound:
            return "Plans could not be loaded. Please try again in a moment."
        case PurchaseError.eligibilityUnavailable:
            return "We couldn’t verify this offer, so no purchase was made. Please try again."
        case PurchaseError.paymentPending:
            return "Your purchase is waiting for approval. Pro will unlock after Apple confirms it."
        case PurchaseError.underlying(let message):
            return message
        default:
            return "Something went wrong. Please try again in a moment."
        }
    }
}

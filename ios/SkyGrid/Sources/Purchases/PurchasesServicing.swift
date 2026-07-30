import Foundation

/// Ported near-verbatim from Unhook's `PurchasesServicing.swift` — the abstraction
/// itself is app-agnostic; only `RevenueCatConfig.entitlementID` and the API key
/// differ per app.
enum EntitlementStatus: Equatable, Sendable {
    case subscribed
    case notSubscribed
    /// Undeterminable (network/SDK error). Callers must fail-safe to "not
    /// subscribed" rather than granting access on ambiguity.
    case unknown
}

enum PurchasePeriod: Equatable, Sendable {
    case annual
    case monthly
    case weekly
    case lifetime
    case unknown
}

struct PurchaseProduct: Identifiable, Equatable, Sendable {
    let id: String
    /// RevenueCat offering that produced this package. Purchase must resolve this
    /// exact offering again instead of relying on whichever offering is current at
    /// checkout time.
    let offeringID: String
    let storeProductID: String
    let title: String
    let priceLabel: String
    let periodLabel: String?
    var period: PurchasePeriod
    var pricePerMonth: Decimal?
    var pricePerMonthLabel: String?
    var price: Decimal?
    var introductoryPrice: Decimal?
    var introductoryPriceLabel: String?
    var introductoryDescription: String?
    var billingDescription: String?

    init(
        id: String,
        title: String,
        priceLabel: String,
        periodLabel: String?,
        offeringID: String = "preview",
        storeProductID: String? = nil,
        period: PurchasePeriod = .unknown,
        pricePerMonth: Decimal? = nil,
        pricePerMonthLabel: String? = nil,
        price: Decimal? = nil,
        introductoryPrice: Decimal? = nil,
        introductoryPriceLabel: String? = nil,
        introductoryDescription: String? = nil,
        billingDescription: String? = nil
    ) {
        self.id = id
        self.offeringID = offeringID
        self.storeProductID = storeProductID ?? id
        self.title = title
        self.priceLabel = priceLabel
        self.periodLabel = periodLabel
        self.period = period
        self.pricePerMonth = pricePerMonth
        self.pricePerMonthLabel = pricePerMonthLabel
        self.price = price
        self.introductoryPrice = introductoryPrice
        self.introductoryPriceLabel = introductoryPriceLabel
        self.introductoryDescription = introductoryDescription
        self.billingDescription = billingDescription
    }

    var displayedPriceLabel: String { introductoryPriceLabel ?? priceLabel }
    var displayedPrice: Decimal? { introductoryPrice ?? price }
}

struct PaywallContent: Equatable, Sendable {
    let offeringID: String
    let products: [PurchaseProduct]
}

enum PurchaseError: Error, Equatable, Sendable {
    case userCancelled
    case configurationMissing
    case noOfferingAvailable
    case productNotFound
    case underlying(String)
}

/// A truthful unavailable state, not a local StoreKit simulation. Production
/// products and localized prices are supplied exclusively by RevenueCat/StoreKit.
struct UnconfiguredPurchasesService: PurchasesServicing {
    func entitlementStatus() async -> EntitlementStatus { .unknown }

    func fetchPaywall() async throws -> PaywallContent {
        throw PurchaseError.configurationMissing
    }

    func purchase(product: PurchaseProduct) async throws -> EntitlementStatus {
        throw PurchaseError.configurationMissing
    }

    func restorePurchases() async throws -> EntitlementStatus {
        throw PurchaseError.configurationMissing
    }
}

protocol PurchasesServicing: Sendable {
    func entitlementStatus() async -> EntitlementStatus
    func fetchPaywall() async throws -> PaywallContent
    func purchase(product: PurchaseProduct) async throws -> EntitlementStatus
    func restorePurchases() async throws -> EntitlementStatus
}

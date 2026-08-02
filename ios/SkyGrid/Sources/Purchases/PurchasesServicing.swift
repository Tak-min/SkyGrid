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

/// The commercial plans exposed by Sky Grid. This intentionally has exactly four
/// cases; network verification remains a separate `EntitlementStatus` concern.
enum SubscriptionPlan: String, CaseIterable, Equatable, Sendable {
    case free
    case monthly
    case annual
    case lifetime

    var homeLabel: String {
        switch self {
        case .free: return "Free"
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        case .lifetime: return "Lifetime"
        }
    }

    var statusSymbol: String {
        switch self {
        case .free: return "sparkles"
        case .monthly: return "calendar"
        case .annual: return "calendar.badge.checkmark"
        case .lifetime: return "infinity"
        }
    }

    /// A current paid subscription should be shown as status, not as another
    /// purchase invitation. The free and unresolved states retain a manual way
    /// to view the available plans.
    var canOpenPaywall: Bool {
        switch self {
        case .free:
            return true
        case .monthly, .annual, .lifetime:
            return false
        }
    }

    var isPaid: Bool { self != .free }
}

struct EntitlementSummary: Equatable, Sendable {
    let status: EntitlementStatus
    let plan: SubscriptionPlan

    static let free = EntitlementSummary(status: .notSubscribed, plan: .free)
    /// We never turn an unresolved entitlement check into paid access. The
    /// verification state remains `.unknown`, while the product display stays
    /// inside the four-plan contract.
    static let unknown = EntitlementSummary(status: .unknown, plan: .free)
}

enum PurchasePeriod: Equatable, Sendable {
    case annual
    case monthly
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
        self.billingDescription = billingDescription
    }
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
    func entitlementSummary() async -> EntitlementSummary
    func fetchPaywall() async throws -> PaywallContent
    func purchase(product: PurchaseProduct) async throws -> EntitlementStatus
    func restorePurchases() async throws -> EntitlementStatus
}

extension PurchasesServicing {
    func entitlementSummary() async -> EntitlementSummary {
        switch await entitlementStatus() {
        case .notSubscribed: return .free
        // A custom purchase service cannot infer a paid plan without RevenueCat's
        // product mapping. Keep the UI in the four-plan model until it can.
        case .subscribed: return EntitlementSummary(status: .subscribed, plan: .monthly)
        case .unknown: return .unknown
        }
    }
}

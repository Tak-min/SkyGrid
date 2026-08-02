import Foundation
import RevenueCat
import os

/// Ported near-verbatim from Unhook's `RevenueCatService.swift` — Phase 2 only.
struct RevenueCatService: PurchasesServicing {
    private static let logger = Logger(subsystem: "com.takmin.skygrid", category: "purchases")

    func entitlementStatus() async -> EntitlementStatus {
        do {
            return Self.status(from: try await Purchases.shared.customerInfo())
        } catch {
            Self.logger.error("Failed to fetch customer info: \(error.localizedDescription)")
            return .unknown
        }
    }

    func entitlementSummary() async -> EntitlementSummary {
        do {
            let info = try await Purchases.shared.customerInfo()
            guard let entitlement = info.entitlements[RevenueCatConfig.entitlementID], entitlement.isActive else {
                return .free
            }
            return EntitlementSummary(
                status: .subscribed,
                plan: await Self.plan(for: entitlement)
            )
        } catch {
            Self.logger.error("Failed to fetch subscription plan: \(error.localizedDescription)")
            return .unknown
        }
    }

    func fetchPaywall() async throws -> PaywallContent {
        let offerings = try await Purchases.shared.offerings()
        guard let offering = offerings.current else { throw PurchaseError.noOfferingAvailable }
        let products = offering.availablePackages.compactMap { pkg -> PurchaseProduct? in
            let period = Self.period(for: pkg.packageType)
            // The catalog is deliberately restricted to the three paid variants
            // that correspond to Sky Grid's four-state model (plus Free).
            guard [.monthly, .annual, .lifetime].contains(period) else { return nil }
            let pricePerMonth = pkg.storeProduct.pricePerMonth?.decimalValue
            let pricePerMonthLabel = pricePerMonth.flatMap { ppm in
                pkg.storeProduct.priceFormatter?.string(from: ppm as NSDecimalNumber)
            }
            return PurchaseProduct(
                id: pkg.identifier,
                title: pkg.storeProduct.localizedTitle,
                priceLabel: pkg.storeProduct.localizedPriceString,
                periodLabel: Self.periodLabel(for: pkg.packageType),
                offeringID: offering.identifier,
                storeProductID: pkg.storeProduct.productIdentifier,
                period: period,
                pricePerMonth: pricePerMonth,
                pricePerMonthLabel: pricePerMonthLabel,
                price: pkg.storeProduct.price,
                billingDescription: Self.billingDescription(
                    price: pkg.storeProduct.localizedPriceString,
                    period: period
                )
            )
        }
        guard !products.isEmpty else { throw PurchaseError.noOfferingAvailable }
        return PaywallContent(offeringID: offering.identifier, products: products)
    }

    func purchase(product: PurchaseProduct) async throws -> EntitlementStatus {
        let offerings = try await Purchases.shared.offerings()
        guard let offering = offerings.offering(identifier: product.offeringID) else {
            throw PurchaseError.noOfferingAvailable
        }
        guard let pkg = offering.availablePackages.first(where: {
            $0.identifier == product.id && $0.storeProduct.productIdentifier == product.storeProductID
        }) else {
            throw PurchaseError.productNotFound
        }
        do {
            let result = try await Purchases.shared.purchase(package: pkg)
            if result.userCancelled { throw PurchaseError.userCancelled }
            return Self.status(from: result.customerInfo)
        } catch let e as PurchaseError {
            throw e
        } catch {
            Self.logger.error("Purchase failed: \(error.localizedDescription)")
            throw PurchaseError.underlying(error.localizedDescription)
        }
    }

    func restorePurchases() async throws -> EntitlementStatus {
        do {
            return Self.status(from: try await Purchases.shared.restorePurchases())
        } catch {
            Self.logger.error("Restore failed: \(error.localizedDescription)")
            throw PurchaseError.underlying(error.localizedDescription)
        }
    }

    private static func status(from info: CustomerInfo) -> EntitlementStatus {
        info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true ? .subscribed : .notSubscribed
    }

    private static func plan(for entitlement: EntitlementInfo) async -> SubscriptionPlan {
        let period = await packagePeriod(for: entitlement.productIdentifier)
        // A paid entitlement from an older catalog keeps access, while its
        // display remains inside the same four-plan contract.
        switch period {
        case .monthly: return .monthly
        case .annual: return .annual
        case .lifetime: return .lifetime
        default:
            // A lifetime entitlement has no expiry even when an old offering is no
            // longer returned by RevenueCat. A legacy subscription with an
            // unresolved package remains paid and is shown as the conservative
            // recurring plan rather than inventing a fifth display state.
            return entitlement.expirationDate == nil ? .lifetime : .monthly
        }
    }

    private static func packagePeriod(for productID: String) async -> PurchasePeriod {
        if let offerings = try? await Purchases.shared.offerings(),
           let package = offerings.all.values
            .flatMap(\.availablePackages)
            .first(where: { $0.storeProduct.productIdentifier == productID }) {
            return period(for: package.packageType)
        }

        switch productID {
        case "com.takmin.skygrid.pro.monthly": return .monthly
        case "com.takmin.skygrid.pro.annual": return .annual
        case "com.takmin.skygrid.pro.lifetime": return .lifetime
        default: return .unknown
        }
    }

    private static func periodLabel(for type: PackageType) -> String? {
        switch type {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        default: return nil
        }
    }

    private static func period(for type: PackageType) -> PurchasePeriod {
        switch type {
        case .annual: return .annual
        case .monthly: return .monthly
        case .lifetime: return .lifetime
        default: return .unknown
        }
    }

    private static func billingDescription(price: String, period: PurchasePeriod) -> String? {
        switch period {
        case .annual: return "Then \(price) per year. Auto-renews unless cancelled."
        case .monthly: return "\(price) per month. Auto-renews unless cancelled."
        case .lifetime: return "One payment. No renewal."
        case .unknown: return nil
        }
    }

}

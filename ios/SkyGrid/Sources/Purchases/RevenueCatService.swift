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

    func fetchPaywall() async throws -> PaywallContent {
        let offerings = try await Purchases.shared.offerings()
        guard let offering = offerings.current else { throw PurchaseError.noOfferingAvailable }
        let packages = offering.availablePackages
        let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            productIdentifiers: packages.map(\.storeProduct.productIdentifier)
        )
        let products = packages.map { pkg in
            let pricePerMonth = pkg.storeProduct.pricePerMonth?.decimalValue
            let pricePerMonthLabel = pricePerMonth.flatMap { ppm in
                pkg.storeProduct.priceFormatter?.string(from: ppm as NSDecimalNumber)
            }
            let intro = pkg.storeProduct.introductoryDiscount
            let isEligibleForIntro = eligibility[pkg.storeProduct.productIdentifier]?.status.isEligible == true
            let hasDiscountedIntroPrice = isEligibleForIntro && intro?.paymentMode != .freeTrial
            return PurchaseProduct(
                id: pkg.identifier,
                title: pkg.storeProduct.localizedTitle,
                priceLabel: pkg.storeProduct.localizedPriceString,
                periodLabel: Self.periodLabel(for: pkg.packageType),
                offeringID: offering.identifier,
                storeProductID: pkg.storeProduct.productIdentifier,
                period: Self.period(for: pkg.packageType),
                pricePerMonth: pricePerMonth,
                pricePerMonthLabel: pricePerMonthLabel,
                price: pkg.storeProduct.price,
                introductoryPrice: hasDiscountedIntroPrice ? intro?.price : nil,
                introductoryPriceLabel: hasDiscountedIntroPrice ? intro?.localizedPriceString : nil,
                introductoryDescription: isEligibleForIntro ? Self.introDescription(for: intro) : nil,
                billingDescription: Self.billingDescription(
                    price: pkg.storeProduct.localizedPriceString,
                    period: Self.period(for: pkg.packageType)
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

    private static func periodLabel(for type: PackageType) -> String? {
        switch type {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .lifetime: return "Lifetime"
        default: return nil
        }
    }

    private static func period(for type: PackageType) -> PurchasePeriod {
        switch type {
        case .annual: return .annual
        case .monthly: return .monthly
        case .weekly: return .weekly
        case .lifetime: return .lifetime
        default: return .unknown
        }
    }

    private static func billingDescription(price: String, period: PurchasePeriod) -> String? {
        switch period {
        case .annual: return "Then \(price) per year. Auto-renews unless cancelled."
        case .monthly: return "\(price) per month. Auto-renews unless cancelled."
        case .weekly: return "\(price) per week. Auto-renews unless cancelled."
        case .lifetime: return "One payment. No renewal."
        case .unknown: return nil
        }
    }

    private static func introDescription(for discount: StoreProductDiscount?) -> String? {
        guard let discount else { return nil }
        let duration = durationDescription(for: discount.subscriptionPeriod, count: discount.numberOfPeriods)
        switch discount.paymentMode {
        case .freeTrial:
            return "\(duration) free trial."
        case .payAsYouGo, .payUpFront:
            return "Introductory price for \(duration)."
        @unknown default:
            return nil
        }
    }

    private static func durationDescription(for period: SubscriptionPeriod, count: Int) -> String {
        let value = period.value * count
        let unit: String
        switch period.unit {
        case .day: unit = value == 1 ? "day" : "days"
        case .week: unit = value == 1 ? "week" : "weeks"
        case .month: unit = value == 1 ? "month" : "months"
        case .year: unit = value == 1 ? "year" : "years"
        @unknown default: unit = "period"
        }
        return "\(value)-\(unit)"
    }
}

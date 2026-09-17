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
        let offerings: Offerings
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            // Do not present an empty or invented local price list when the
            // storefront cannot be reached. RevenueCat/StoreKit remain the
            // price authority.
            Self.logger.error("RevenueCat offerings request failed")
            throw PurchaseError.underlying("Plans could not be reached. Check your connection and try again.")
        }
        guard let offering = offerings.current else {
            Self.logger.error("RevenueCat returned no current offering")
            throw PurchaseError.noOfferingAvailable
        }
        let products = offering.availablePackages.compactMap { pkg -> PurchaseProduct? in
            guard pkg.storeProduct.productIdentifier != RevenueCatConfig.secondChanceProductID else {
                return nil
            }
            let period = Self.period(
                for: pkg.packageType,
                productID: pkg.storeProduct.productIdentifier
            )
            // The catalog is deliberately restricted to the three paid variants
            // that correspond to Sky Grid's four-state model (plus Free).
            guard [.monthly, .annual, .lifetime].contains(period) else { return nil }
            let currencyCode = pkg.storeProduct.priceFormatter?.currencyCode
            let priceLabel = Self.localizedPrice(pkg.storeProduct.price, currencyCode: currencyCode)
            let pricePerMonth = pkg.storeProduct.pricePerMonth?.decimalValue
            let pricePerMonthLabel = pricePerMonth.flatMap { ppm in
                Self.localizedPrice(ppm, currencyCode: currencyCode)
            }
            return PurchaseProduct(
                id: pkg.identifier,
                title: pkg.storeProduct.localizedTitle,
                priceLabel: priceLabel,
                periodLabel: Self.periodLabel(for: period),
                offeringID: offering.identifier,
                storeProductID: pkg.storeProduct.productIdentifier,
                period: period,
                pricePerMonth: pricePerMonth,
                pricePerMonthLabel: pricePerMonthLabel,
                price: pkg.storeProduct.price,
                billingDescription: Self.billingDescription(price: priceLabel, period: period)
            )
        }
        guard !products.isEmpty else {
            // A non-empty Offering can still be unusable if the dashboard uses
            // a custom package type. The product-ID fallback above recognises
            // only our approved catalog; this log distinguishes a catalog
            // mismatch from a missing current Offering without recording a
            // person or product identifier.
            Self.logger.error("RevenueCat current offering had \(offering.availablePackages.count, privacy: .public) packages but no recognised Sky Grid products")
            throw PurchaseError.noOfferingAvailable
        }
        return PaywallContent(offeringID: offering.identifier, products: products)
    }

    func fetchSecondChanceOffer() async throws -> SecondChanceOffer? {
        let offerings: Offerings
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            Self.logger.error("RevenueCat introductory-offer request failed")
            throw PurchaseError.eligibilityUnavailable
        }
        guard let offering = offerings.offering(identifier: RevenueCatConfig.secondChanceOfferingID),
              let package = offering.availablePackages.first(where: {
                  $0.storeProduct.productIdentifier == RevenueCatConfig.secondChanceProductID
              }),
              let discount = package.storeProduct.introductoryDiscount,
              discount.type == .introductory,
              discount.paymentMode == .payAsYouGo,
              discount.subscriptionPeriod.unit == .month,
              discount.subscriptionPeriod.value == 1,
              discount.numberOfPeriods == 1,
              discount.price < package.storeProduct.price
        else {
            // No product, no intro metadata, or terms other than the approved
            // one-month pay-as-you-go discount all mean “do not show”.
            return nil
        }

        let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            product: package.storeProduct
        )
        switch eligibility {
        case .eligible:
            let currencyCode = package.storeProduct.priceFormatter?.currencyCode
            let product = Self.purchaseProduct(from: package, offeringID: offering.identifier)
            return SecondChanceOffer(
                product: product,
                introductoryPriceLabel: Self.localizedPrice(discount.price, currencyCode: currencyCode),
                savingsLabel: Self.localizedPrice(
                    package.storeProduct.price - discount.price,
                    currencyCode: currencyCode
                ),
                renewalPriceLabel: Self.localizedPrice(package.storeProduct.price, currencyCode: currencyCode)
            )
        case .ineligible, .noIntroOfferExists:
            return nil
        case .unknown:
            throw PurchaseError.eligibilityUnavailable
        @unknown default:
            throw PurchaseError.eligibilityUnavailable
        }
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
        } catch ErrorCode.paymentPendingError {
            throw PurchaseError.paymentPending
        } catch {
            Self.logger.error("Purchase failed: \(error.localizedDescription)")
            throw PurchaseError.underlying(error.localizedDescription)
        }
    }

    func purchaseSecondChance(product: PurchaseProduct) async throws -> EntitlementStatus {
        let offerings = try await Purchases.shared.offerings()
        guard let offering = offerings.offering(identifier: RevenueCatConfig.secondChanceOfferingID),
              offering.identifier == product.offeringID,
              let package = offering.availablePackages.first(where: {
                  $0.identifier == product.id
                      && $0.storeProduct.productIdentifier == product.storeProductID
                      && $0.storeProduct.productIdentifier == RevenueCatConfig.secondChanceProductID
              }),
              let discount = package.storeProduct.introductoryDiscount,
              discount.type == .introductory,
              discount.paymentMode == .payAsYouGo,
              discount.subscriptionPeriod.unit == .month,
              discount.subscriptionPeriod.value == 1,
              discount.numberOfPeriods == 1,
              discount.price < package.storeProduct.price
        else {
            throw PurchaseError.productNotFound
        }

        let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            product: package.storeProduct
        )
        guard eligibility == .eligible else {
            // Never fall through to a regular-price purchase after showing intro
            // terms. Another device may have consumed eligibility since loading.
            throw PurchaseError.eligibilityUnavailable
        }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { throw PurchaseError.userCancelled }
            return Self.status(from: result.customerInfo)
        } catch let error as PurchaseError {
            throw error
        } catch ErrorCode.paymentPendingError {
            throw PurchaseError.paymentPending
        } catch {
            Self.logger.error("Second-chance purchase failed: \(error.localizedDescription)")
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
            return period(for: package.packageType, productID: productID)
        }

        return canonicalProductPeriod(for: productID)
    }

    private static func periodLabel(for period: PurchasePeriod) -> String? {
        switch period {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        case .unknown: return nil
        }
    }

    private static func purchaseProduct(from package: Package, offeringID: String) -> PurchaseProduct {
        let period = period(
            for: package.packageType,
            productID: package.storeProduct.productIdentifier
        )
        let currencyCode = package.storeProduct.priceFormatter?.currencyCode
        let priceLabel = localizedPrice(package.storeProduct.price, currencyCode: currencyCode)
        let pricePerMonth = package.storeProduct.pricePerMonth?.decimalValue
        return PurchaseProduct(
            id: package.identifier,
            title: package.storeProduct.localizedTitle,
            priceLabel: priceLabel,
            periodLabel: periodLabel(for: period),
            offeringID: offeringID,
            storeProductID: package.storeProduct.productIdentifier,
            period: period,
            pricePerMonth: pricePerMonth,
            pricePerMonthLabel: pricePerMonth.map { localizedPrice($0, currencyCode: currencyCode) },
            price: package.storeProduct.price,
            billingDescription: billingDescription(price: priceLabel, period: period)
        )
    }

    /// The app's currently-selected in-app language, falling back to the device's
    /// preferred language the same way `L10n.string` resolves it — kept in sync so a
    /// price and the text around it are always formatted for the same language,
    /// independent of the device's system locale (see `AppLanguage.swift`).
    private static func currentAppLanguage() -> AppLanguage {
        LocalDefaults.selectedLanguageCode.flatMap(AppLanguage.init(rawValue:)) ?? AppLanguage.inferred()
    }

    /// Formats a raw StoreKit/RevenueCat price using the app's selected language
    /// rather than `Product.localizedPriceString`/`priceFormatter`, both of which are
    /// pinned to the device's system locale. `currencyCode` still comes from the
    /// store (the App Store storefront decides currency, not the display language).
    private static func localizedPrice(_ price: Decimal, currencyCode: String?) -> String {
        price.formatted(.currency(code: currencyCode ?? "USD").locale(currentAppLanguage().locale))
    }

    /// RevenueCat's standard package types remain the primary source. A custom
    /// package is also valid when — and only when — it wraps one of Sky Grid's
    /// approved App Store products. This prevents a dashboard naming change from
    /// turning a real product list into an empty paywall, while keeping unknown
    /// products out of the purchase UI.
    static func period(for type: PackageType, productID: String) -> PurchasePeriod {
        switch type {
        case .annual: return .annual
        case .monthly: return .monthly
        case .lifetime: return .lifetime
        case .custom, .unknown: return canonicalProductPeriod(for: productID)
        default: return .unknown
        }
    }

    private static func canonicalProductPeriod(for productID: String) -> PurchasePeriod {
        switch productID {
        case "com.takmin.skygrid.pro.monthly": return .monthly
        case RevenueCatConfig.secondChanceProductID: return .monthly
        case "com.takmin.skygrid.pro.annual": return .annual
        case "com.takmin.skygrid.pro.lifetime": return .lifetime
        default: return .unknown
        }
    }

    private static func billingDescription(price: String, period: PurchasePeriod) -> String? {
        switch period {
        case .annual: return String(format: L10n.string("paywall.billing.thenPerYear"), price)
        case .monthly: return String(format: L10n.string("paywall.billing.perMonth"), price)
        case .lifetime: return L10n.string("paywall.billing.onePaymentNoRenewal")
        case .unknown: return nil
        }
    }

}

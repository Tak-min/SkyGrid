import SwiftUI

/// Step 3: the only step where price, renewal terms, restoration, and the legal
/// links appear — together, ahead of any purchase action (App Store Guideline
/// 3.1.2; see the doc comment on `PaywallView`). All three plans are shown as one
/// list rather than a "selected + other plans" split.
struct PaywallPlanStepView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let flow: PaywallFlow
    let entryPoint: PaywallEntryPoint
    let viewModel: PaywallViewModel
    @Binding var selectedProductID: String?
    let onPurchase: (PurchaseProduct) -> Void
    let onRetry: () -> Void
    let onRestore: () -> Void
    let onContinueWithFree: () -> Void

    var body: some View {
        PaywallStepScaffold(flow: flow, step: .plan) {
            // The automatic-reminder flows (`.ritualMilestone`, `.firstUnlock`) never
            // show PaywallValueStepView's hero, so this is the only place their
            // funnel names the product at all. Keep
            // it here (not conditioned on entry point) so every flow shape shows
            // price and product identity together, ahead of purchase.
            Text("SKY GRID PRO")
                .font(SGFont.caption(11))
                .tracking(1.5)
                .foregroundStyle(SGT.ink3)
            content
        } cta: {
            ctaArea
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            VStack(spacing: SGSpacing.md) {
                ProgressView()
                Text(entryPoint.requiresEntitlementVerification ? L10n.string("paywall.plan.checkingProAccess") : L10n.string("paywall.plan.loadingPlans"))
                    .font(SGFont.caption(13))
                    .foregroundStyle(SGT.ink2)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
        case .entitlementUnavailable:
            // The container short-circuits this state to `PaywallStatusView`
            // before any step renders — see PaywallView.body.
            EmptyView()
        case .failed(let message):
            VStack(alignment: .leading, spacing: SGSpacing.md) {
                Text(message)
                    .font(SGFont.body())
                    .foregroundStyle(SGT.ink2)
                Button("Try again", action: onRetry)
                    .buttonStyle(SkySecondaryButtonStyle())
            }
        case .loaded(let paywallContent):
            VStack(alignment: .leading, spacing: SGSpacing.md) {
                Text("CHOOSE A PLAN")
                    .font(SGFont.caption(11))
                    .tracking(1.4)
                    .foregroundStyle(SGT.ink3)

                ForEach(orderedProducts(in: paywallContent)) { product in
                    PlanOptionRow(
                        product: product,
                        isSelected: product.id == selectedProduct(in: paywallContent)?.id,
                        isRecommended: isBestValue(product, in: paywallContent)
                    ) {
                        selectedProductID = product.id
                        PaywallAnalytics.record(.planSelected, entryPoint: entryPoint, period: product.period)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(SGFont.caption(13))
                        .foregroundStyle(.red)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    restoreAndLegal(includeFreePath: false)
                        .padding(.top, SGSpacing.sm)
                }
            }
        }
    }

    @ViewBuilder
    private var ctaArea: some View {
        if case .loaded(let paywallContent) = viewModel.state, let selection = selectedProduct(in: paywallContent) {
            Button(action: { onPurchase(selection) }) {
                if viewModel.isPurchasing {
                    ProgressView().tint(SGT.background)
                } else {
                    Text(primaryActionTitle(for: selection))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(SkyPrimaryButtonStyle())
            .disabled(viewModel.isPurchasing)
        }

        if dynamicTypeSize.isAccessibilitySize {
            Button("Continue with Free", action: onContinueWithFree)
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
                .frame(minHeight: 44)
                .disabled(viewModel.isPurchasing)
        } else {
            restoreAndLegal(includeFreePath: true)
        }
    }

    private func restoreAndLegal(includeFreePath: Bool) -> some View {
        VStack(spacing: SGSpacing.md) {
            Button("Restore purchases", action: onRestore)
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
                .disabled(viewModel.isPurchasing)

            HStack(spacing: SGSpacing.md) {
                Link("Terms of Use", destination: PaywallLegal.termsURL)
                if let privacyURL = PaywallLegal.privacyURL {
                    Text("·").foregroundStyle(SGT.ink3)
                    Link("Privacy Policy", destination: privacyURL)
                }
            }
            .font(SGFont.caption(12))
            .foregroundStyle(SGT.ink3)

            if includeFreePath {
                Button("Continue with Free", action: onContinueWithFree)
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
                    .disabled(viewModel.isPurchasing)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func selectedProduct(in content: PaywallContent) -> PurchaseProduct? {
        content.products.first(where: { $0.id == selectedProductID }) ?? recommendedProduct(in: content)
    }

    private func recommendedProduct(in content: PaywallContent) -> PurchaseProduct? {
        content.products.first(where: { $0.period == .annual }) ?? content.products.first
    }

    /// "Best value" is a pricing claim, not a styling choice. Do not make it
    /// unless the annual product's regular total is objectively lower than twelve
    /// months of the available monthly plan.
    private func isBestValue(_ product: PurchaseProduct, in content: PaywallContent) -> Bool {
        guard product.period == .annual,
              let annualPrice = product.price,
              let monthlyPrice = content.products.first(where: { $0.period == .monthly })?.price
        else { return false }
        return annualPrice < monthlyPrice * 12
    }

    /// RevenueCat remains the price authority. We only impose a stable visual
    /// order: annual, monthly, then lifetime.
    private func orderedProducts(in content: PaywallContent) -> [PurchaseProduct] {
        content.products.sorted { lhs, rhs in
            let order: (PurchaseProduct) -> Int = { product in
                switch product.period {
                case .annual: return 0
                case .monthly: return 1
                case .lifetime: return 2
                case .unknown: return 3
                }
            }
            return order(lhs) == order(rhs) ? lhs.title < rhs.title : order(lhs) < order(rhs)
        }
    }

    private func primaryActionTitle(for product: PurchaseProduct) -> String {
        "Continue with \(product.periodLabel ?? "Pro")"
    }
}

private struct PlanOptionRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let product: PurchaseProduct
    let isSelected: Bool
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: SGSpacing.md) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? SGT.ink : SGT.ink3)
                    .contentTransition(.symbolEffect(.replace))
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 4) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            planName
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer(minLength: SGSpacing.sm)
                            price
                                .fixedSize(horizontal: true, vertical: false)
                        }

                        VStack(alignment: .leading, spacing: SGSpacing.xs) {
                            planName
                            price
                        }
                    }
                    if let equivalent = product.pricePerMonthLabel, product.period == .annual {
                        Text(String(format: L10n.string("paywall.equivalentPerMonth"), equivalent))
                            .font(SGFont.caption(12))
                            .foregroundStyle(SGT.ink2)
                    }
                    if let billing = product.billingDescription {
                        Text(billing)
                            .font(SGFont.caption(12))
                            .foregroundStyle(SGT.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(SGSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? SGT.fill : SGT.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? SGT.ink.opacity(0.44) : SGT.rule, lineWidth: 1)
            }
            .skyAnimation(SGMotion.settle, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var planName: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    planPeriod
                    if isRecommended {
                        Text("Best value")
                            .font(SGFont.caption(10))
                            .foregroundStyle(SGT.ink2)
                    }
                }
            } else {
                HStack(spacing: SGSpacing.xs) {
                    planPeriod
                    if isRecommended {
                        Text("BEST VALUE")
                            .font(SGFont.caption(10))
                            .tracking(0.8)
                            .foregroundStyle(SGT.background)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(SGT.ink, in: Capsule())
                    }
                }
            }
        }
    }

    private var planPeriod: some View {
        Text(product.periodLabel ?? product.title)
            .font(SGFont.body(16))
            .foregroundStyle(SGT.ink)
    }

    private var price: some View {
        // The total recurring price is always prominent and never presented as
        // a struck-through former price.
        Text(product.priceLabel)
            .font(SGFont.numeric(20, weight: .medium))
            .foregroundStyle(SGT.ink)
    }
}

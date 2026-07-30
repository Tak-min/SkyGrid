import SwiftUI

/// A transparent StoreKit paywall: total prices, renewal terms, restoration, and
/// a free path are all visible before a person initiates a purchase.
struct PaywallView: View {
    @State private var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss
    let entryPoint: PaywallEntryPoint
    let onEntitlementGranted: () -> Void
    let onContinueWithFree: () -> Void

    @State private var selectedProductID: String?
    @State private var showExitOffer = false
    @State private var isPreparingExitOffer = false

    init(
        purchases: any PurchasesServicing,
        entryPoint: PaywallEntryPoint = .settings,
        onEntitlementGranted: @escaping () -> Void,
        onContinueWithFree: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: PaywallViewModel(purchases: purchases))
        self.entryPoint = entryPoint
        self.onEntitlementGranted = onEntitlementGranted
        self.onContinueWithFree = onContinueWithFree
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SGSpacing.xl) {
                    hero
                    benefits
                    content
                    restoreAndLegal
                }
                .padding(SGSpacing.xl)
                .padding(.bottom, 24)
            }
            .background(paywallBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { requestExitOffer() }
                        .foregroundStyle(SGT.ink2)
                        .disabled(isPreparingExitOffer || viewModel.isPurchasing)
                }
            }
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.state) { _, state in
            guard case .loaded(let content) = state,
                  selectedProductID == nil
            else { return }
            selectedProductID = recommendedProduct(in: content)?.id
        }
        .sheet(isPresented: $showExitOffer) {
            if let configuration = ExitOfferConfiguration.current {
                ExitOfferCodeView(configuration: configuration) {
                    Task {
                        if await viewModel.refreshedEntitlementStatus() == .subscribed {
                            onEntitlementGranted()
                        } else {
                            onContinueWithFree()
                        }
                        dismiss()
                    }
                }
                .presentationDetents([.large])
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            RitualGridMark()
                .frame(maxWidth: .infinity)
                .frame(height: 126)
            Text("SKY GRID PRO")
                .font(SGFont.caption(11))
                .tracking(1.5)
                .foregroundStyle(SGT.ink3)
            Text(entryPoint.headline)
                .font(SGFont.serifTitle(34))
                .foregroundStyle(SGT.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            PaywallBenefit(
                symbol: "calendar",
                title: "Your full archive",
                detail: "Keep every captured sky beyond the Free 30-day view."
            )
            PaywallBenefit(
                symbol: "square.grid.3x3",
                title: "The complete year",
                detail: "See the season move through every square of your Sky Grid."
            )
            PaywallBenefit(
                symbol: "square.and.arrow.up",
                title: "A full-year share card",
                detail: "Export the complete color record when there is a year to share."
            )
        }
        .padding(SGSpacing.lg)
        .quietCard()
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 180)
        case .failed(let message):
            VStack(alignment: .leading, spacing: SGSpacing.md) {
                Text(message)
                    .font(SGFont.body())
                    .foregroundStyle(SGT.ink2)
                Button("Try again") { Task { await viewModel.load() } }
                    .buttonStyle(SkySecondaryButtonStyle())
            }
        case .loaded(let paywallContent):
            let selection = selectedProduct(in: paywallContent)
            VStack(alignment: .leading, spacing: SGSpacing.md) {
                Text("CHOOSE A PLAN")
                    .font(SGFont.caption(11))
                    .tracking(1.4)
                    .foregroundStyle(SGT.ink3)

                ForEach(paywallContent.products) { product in
                    PlanOptionRow(
                        product: product,
                        isSelected: selectedProductID == product.id,
                        isRecommended: product.period == .annual
                    ) {
                        selectedProductID = product.id
                    }
                }

                if let selection {
                    Button(action: { purchase(selection) }) {
                        if viewModel.isPurchasing {
                            ProgressView().tint(SGT.background)
                        } else {
                            Text(primaryActionTitle(for: selection))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(SkyPrimaryButtonStyle())
                    .disabled(viewModel.isPurchasing)

                    if let introductory = selection.introductoryDescription {
                        Text("\(introductory) \(selection.billingDescription ?? "")")
                            .font(SGFont.caption(12))
                            .foregroundStyle(SGT.ink2)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if let billing = selection.billingDescription {
                        Text(billing)
                            .font(SGFont.caption(12))
                            .foregroundStyle(SGT.ink2)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(SGFont.caption(13))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var restoreAndLegal: some View {
        VStack(spacing: SGSpacing.md) {
            Button("Restore purchases") {
                Task {
                    if await viewModel.restore() {
                        onEntitlementGranted()
                        dismiss()
                    }
                }
            }
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

            Button(isPreparingExitOffer ? "Just a moment…" : "Continue with Free") {
                continueWithFree()
            }
            .font(SGFont.body(15))
            .foregroundStyle(SGT.ink2)
            .disabled(isPreparingExitOffer || viewModel.isPurchasing)
            .padding(.top, SGSpacing.xs)
        }
        .frame(maxWidth: .infinity)
    }

    private var paywallBackground: some View {
        LinearGradient(
            colors: [SGT.fill, SGT.background, SGT.background],
            startPoint: .top,
            endPoint: .center
        )
    }

    private func selectedProduct(in content: PaywallContent) -> PurchaseProduct? {
        content.products.first(where: { $0.id == selectedProductID }) ?? recommendedProduct(in: content)
    }

    private func recommendedProduct(in content: PaywallContent) -> PurchaseProduct? {
        content.products.first(where: { $0.period == .annual }) ?? content.products.first
    }

    private func primaryActionTitle(for product: PurchaseProduct) -> String {
        if product.introductoryDescription?.localizedCaseInsensitiveContains("free trial") == true {
            return "Start free trial"
        }
        return "Choose \(product.periodLabel ?? "Pro")"
    }

    private func purchase(_ product: PurchaseProduct) {
        Task {
            if await viewModel.purchase(product: product) {
                onEntitlementGranted()
                dismiss()
            }
        }
    }

    /// Choosing Free is a complete, one-tap choice. An optional offer may only be
    /// shown after the person explicitly closes the onboarding paywall.
    private func continueWithFree() {
        onContinueWithFree()
        dismiss()
    }

    private func requestExitOffer() {
        let configuration = ExitOfferConfiguration.current
        let shouldPresent = ExitOfferPolicy.shouldPresent(
            isOnboarding: entryPoint.permitsExitOffer,
            hasBeenPresented: LocalDefaults.didPresentExitOffer,
            configuration: configuration
        )
        guard shouldPresent else {
            continueWithFree()
            return
        }

        LocalDefaults.didPresentExitOffer = true
        isPreparingExitOffer = true
        showExitOffer = true
        isPreparingExitOffer = false
    }
}

private struct PaywallBenefit: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: SGSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 20)
                .foregroundStyle(SGT.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink)
                Text(detail)
                    .font(SGFont.caption(13))
                    .foregroundStyle(SGT.ink2)
            }
        }
    }
}

private struct PlanOptionRow: View {
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
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.periodLabel ?? product.title)
                            .font(SGFont.body(16))
                            .foregroundStyle(SGT.ink)
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
                    if let equivalent = product.pricePerMonthLabel, product.period == .annual {
                        Text("Equivalent to \(equivalent) per month")
                            .font(SGFont.caption(12))
                            .foregroundStyle(SGT.ink2)
                    }
                    if let intro = product.introductoryDescription {
                        Text(intro)
                            .font(SGFont.caption(12))
                            .foregroundStyle(SGT.ink2)
                    }
                }

                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayedPriceLabel)
                        .font(SGFont.numeric(20, weight: .medium))
                        .foregroundStyle(SGT.ink)
                    if product.introductoryPriceLabel != nil {
                        Text(product.priceLabel)
                            .font(SGFont.caption(12))
                            .foregroundStyle(SGT.ink3)
                            .strikethrough()
                    }
                }
            }
            .padding(SGSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? SGT.fill : SGT.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? SGT.ink.opacity(0.44) : SGT.rule, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private enum PaywallLegal {
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static var privacyURL: URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "SkyGridPrivacyPolicyURL") as? String,
              let url = URL(string: rawValue),
              url.scheme?.lowercased() == "https"
        else { return nil }
        return url
    }
}

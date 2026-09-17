import SwiftUI

/// A conditional fourth step inside the existing paywall. It reuses the shared
/// scaffold and purchase state, so `stepViewed` and `dismissed` keep their existing
/// event schema with `step=second_chance`.
struct PaywallSecondChanceStepView: View {
    let flow: PaywallFlow
    let state: PaywallViewModel.SecondChanceState
    let isPurchasing: Bool
    let purchaseError: String?
    let onPurchase: (PurchaseProduct) -> Void
    let onRetry: () -> Void
    let onContinueWithFree: () -> Void

    var body: some View {
        PaywallStepScaffold(flow: flow, step: .secondChance) {
            content
        } cta: {
            cta
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            status(
                title: L10n.string("paywall.secondChance.status.checking.title"),
                detail: L10n.string("paywall.secondChance.status.checking.detail"),
                showsSpinner: true
            )
        case .disconnected:
            status(
                title: L10n.string("paywall.secondChance.status.offline.title"),
                detail: L10n.string("paywall.secondChance.status.offline.detail"),
                showsSpinner: false
            )
        case .unavailable:
            EmptyView()
        case .ready(let offer):
            VStack(alignment: .leading, spacing: SGSpacing.lg) {
                MokuView(state: .pleading, side: 156)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                Text(L10n.string("paywall.secondChance.headline"))
                    .font(SGFont.display(28))
                    .foregroundStyle(SGT.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: SGSpacing.sm) {
                    termRow(L10n.string("paywall.secondChance.term.firstMonth"), value: offer.introductoryPriceLabel)
                    termRow(L10n.string("paywall.secondChance.term.youSave"), value: offer.savingsLabel)
                    termRow(L10n.string("paywall.secondChance.term.thenEachMonth"), value: offer.renewalPriceLabel)
                }
                .padding(SGSpacing.lg)
                .background(SGT.fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text(L10n.string("paywall.secondChance.renewalNotice"))
                    .font(SGFont.caption(13))
                    .foregroundStyle(SGT.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                if let purchaseError {
                    Text(purchaseError)
                        .font(SGFont.caption(13))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var cta: some View {
        switch state {
        case .ready(let offer):
            Button(action: { onPurchase(offer.product) }) {
                if isPurchasing {
                    ProgressView().tint(SGT.background)
                } else {
                    Text(String(format: L10n.string("paywall.tryFirstMonthFor"), offer.introductoryPriceLabel))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(SkyPrimaryButtonStyle())
            .disabled(isPurchasing)

            legalAndFree
        case .disconnected:
            Button(L10n.string("Try again"), action: onRetry)
                .buttonStyle(SkyPrimaryButtonStyle())
            Button(L10n.string("Continue with Free"), action: onContinueWithFree)
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
                .frame(minHeight: 44)
        case .idle, .loading:
            Button(L10n.string("Continue with Free"), action: onContinueWithFree)
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
                .frame(minHeight: 44)
        case .unavailable:
            EmptyView()
        }
    }

    private func status(title: String, detail: String, showsSpinner: Bool) -> some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            MokuView(state: showsSpinner ? .waiting : .error, side: 124)
                .frame(maxWidth: .infinity)
            if showsSpinner {
                ProgressView()
            }
            Text(title)
                .font(SGFont.display(26))
                .foregroundStyle(SGT.ink)
            Text(detail)
                .font(SGFont.body())
                .foregroundStyle(SGT.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func termRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
            Spacer(minLength: SGSpacing.md)
            Text(value)
                .font(SGFont.body(17))
                .foregroundStyle(SGT.ink)
        }
    }

    private var legalAndFree: some View {
        VStack(spacing: SGSpacing.md) {
            HStack(spacing: SGSpacing.md) {
                Link(L10n.string("Terms of Use"), destination: PaywallLegal.termsURL)
                if let privacyURL = PaywallLegal.privacyURL {
                    Text("·").foregroundStyle(SGT.ink3)
                    Link(L10n.string("Privacy Policy"), destination: privacyURL)
                }
            }
            .font(SGFont.caption(12))
            .foregroundStyle(SGT.ink3)

            Button(L10n.string("Continue with Free"), action: onContinueWithFree)
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
                .frame(minHeight: 44)
                .disabled(isPurchasing)
        }
        .frame(maxWidth: .infinity)
    }
}

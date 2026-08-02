import SwiftUI

enum PaywallDismissalReason {
    case close
    case continueWithFree
    case interactiveDismissal
}

/// A transparent, multi-step StoreKit paywall. Price, renewal terms, restoration,
/// and a free path are all visible together on the final (`.plan`) step, ahead of
/// any purchase action — see §8 of `session-handoff-paywall-alarm_2026-08-01.md`
/// for how each constraint (App Store Guideline 3.1.2 among them) is upheld across
/// the step split.
struct PaywallView: View {
    @State private var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss
    let entryPoint: PaywallEntryPoint
    let flow: PaywallFlow
    let onEntitlementGranted: () async -> Void
    let onPresented: () -> Void
    let onDismissed: (PaywallDismissalReason) -> Void

    @State private var step: PaywallStep
    @State private var isMovingBackward = false
    @State private var viewedSteps: Set<PaywallStep> = []
    @State private var selectedProductID: String?
    @State private var hasResolvedExit = false
    @State private var didRecordPresentation = false

    init(
        purchases: any PurchasesServicing,
        entryPoint: PaywallEntryPoint = .settings,
        initialStep: PaywallStep? = nil,
        onEntitlementGranted: @escaping () async -> Void,
        onPresented: @escaping () -> Void = {},
        onDismissed: @escaping (PaywallDismissalReason) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: PaywallViewModel(purchases: purchases))
        self.entryPoint = entryPoint
        let flow = PaywallFlow.make(for: entryPoint)
        self.flow = flow
        _step = State(initialValue: initialStep ?? flow.first)
        self.onEntitlementGranted = onEntitlementGranted
        self.onPresented = onPresented
        self.onDismissed = onDismissed
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.state == .entitlementUnavailable {
                    PaywallStatusView(
                        onRetry: { Task { await preparePaywall() } },
                        onRestore: restorePurchases
                    )
                } else {
                    stepContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != flow.first {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", action: goBack)
                            .foregroundStyle(SGT.ink2)
                            .disabled(viewModel.isPurchasing)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { resolveExit(.close) }
                        .foregroundStyle(SGT.ink2)
                        .disabled(viewModel.isPurchasing)
                }
            }
        }
        .task {
            recordPresentationIfNeeded()
            recordStepViewedIfNeeded(step)
            await preparePaywall()
        }
        .onChange(of: viewModel.state) { _, state in
            guard case .loaded(let content) = state,
                  selectedProductID == nil
            else { return }
            selectedProductID = recommendedProduct(in: content)?.id
        }
        .onChange(of: step) { _, newStep in
            recordStepViewedIfNeeded(newStep)
        }
        .onDisappear {
            guard !hasResolvedExit else { return }
            resolveExit(.interactiveDismissal)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .value:
            PaywallValueStepView(
                flow: flow,
                entryPoint: entryPoint,
                onAdvance: advance,
                onContinueWithFree: continueWithFree
            )
            .transition(stepTransition)
        case .features:
            PaywallFeaturesStepView(
                flow: flow,
                entryPoint: entryPoint,
                showsHeadline: flow.first == .features,
                onAdvance: advance,
                onContinueWithFree: continueWithFree
            )
            .transition(stepTransition)
        case .plan:
            PaywallPlanStepView(
                flow: flow,
                entryPoint: entryPoint,
                viewModel: viewModel,
                selectedProductID: $selectedProductID,
                onPurchase: purchase,
                onRetry: { Task { await preparePaywall() } },
                onRestore: restorePurchases,
                onContinueWithFree: continueWithFree
            )
            .transition(stepTransition)
        }
    }

    /// The plan-step CTA shelf stays fixed; only the reasoning above it moves —
    /// forward and back slide in opposite directions so the motion itself signals
    /// which way the person is navigating.
    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isMovingBackward ? .leading : .trailing).combined(with: .opacity),
            removal: .move(edge: isMovingBackward ? .trailing : .leading).combined(with: .opacity)
        )
    }

    private func advance() {
        guard let next = flow.next(after: step) else { return }
        isMovingBackward = false
        withAnimation(SGMotion.exchange) {
            step = next
        }
    }

    private func goBack() {
        guard let previous = flow.previous(before: step) else { return }
        isMovingBackward = true
        withAnimation(SGMotion.exchange) {
            step = previous
        }
    }

    private func recordStepViewedIfNeeded(_ step: PaywallStep) {
        guard !viewedSteps.contains(step) else { return }
        viewedSteps.insert(step)
        PaywallAnalytics.record(.stepViewed, entryPoint: entryPoint, step: step)
    }

    private func recommendedProduct(in content: PaywallContent) -> PurchaseProduct? {
        content.products.first(where: { $0.period == .annual }) ?? content.products.first
    }

    private func purchase(_ product: PurchaseProduct) {
        Task {
            PaywallAnalytics.record(.purchaseStarted, entryPoint: entryPoint, period: product.period)
            if await viewModel.purchase(product: product) {
                PaywallAnalytics.record(.purchaseConfirmed, entryPoint: entryPoint, period: product.period)
                await onEntitlementGranted()
                hasResolvedExit = true
                dismiss()
            }
        }
    }

    /// Choosing Free is a complete, one-tap choice available on every step.
    private func continueWithFree() {
        resolveExit(.continueWithFree)
    }

    private func preparePaywall() async {
        let status = await viewModel.load(verifyEntitlement: entryPoint.requiresEntitlementVerification)
        guard status == .subscribed else { return }
        await onEntitlementGranted()
        hasResolvedExit = true
        dismiss()
    }

    private func restorePurchases() {
        Task {
            PaywallAnalytics.record(.restoreStarted, entryPoint: entryPoint)
            if await viewModel.restore() {
                PaywallAnalytics.record(.restoreConfirmed, entryPoint: entryPoint)
                await onEntitlementGranted()
                hasResolvedExit = true
                dismiss()
            }
        }
    }

    private func recordPresentationIfNeeded() {
        guard !didRecordPresentation else { return }
        didRecordPresentation = true
        PaywallAnalytics.record(.presented, entryPoint: entryPoint)
        onPresented()
    }

    private func resolveExit(_ reason: PaywallDismissalReason) {
        guard !hasResolvedExit else { return }
        hasResolvedExit = true
        PaywallAnalytics.record(.dismissed, entryPoint: entryPoint, dismissalReason: reason, step: step)
        onDismissed(reason)
        dismiss()
    }
}

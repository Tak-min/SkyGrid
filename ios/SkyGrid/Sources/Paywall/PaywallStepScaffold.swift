import SwiftUI

/// The shared container every paywall step renders inside: a scrollable content
/// area plus a CTA region fixed to the bottom via `.safeAreaInset`, so the primary
/// action and the free path are always on screen without scrolling (see D3 in
/// `session-handoff-paywall-alarm_2026-08-01.md`).
struct PaywallStepScaffold<Content: View, CTA: View>: View {
    let flow: PaywallFlow
    let step: PaywallStep
    /// Lets a step suppress this scaffold's own screen-level Moku mark when that
    /// step already renders an equivalent mark inline (e.g. `PaywallFeaturesStepView`
    /// draws it next to its headline to avoid the two colliding). Defaults to `true`
    /// so every other step keeps the scaffold-drawn mark unchanged.
    var showsScreenMark: Bool = true
    @ViewBuilder var content: () -> Content
    @ViewBuilder var cta: () -> CTA

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SGSpacing.xl) {
                    content()
                }
                // Value and feature steps are intentionally shorter than the
                // pricing step. Center their content in the usable page instead
                // of pinning it to the top and leaving a conspicuous empty lower
                // half above the persistent CTA area.
                .frame(
                    maxWidth: .infinity,
                    minHeight: step == .plan ? 0 : proxy.size.height,
                    alignment: step == .plan ? .topLeading : .center
                )
                .padding(SGSpacing.xl)
                .padding(.bottom, 24)
            }
        }
        .background(PaywallStepScaffold.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if step != .secondChance && showsScreenMark {
                MokuScreenMark(state: .ready, side: 50)
                    .padding(.top, 54)
                    .padding(.trailing, SGSpacing.xl)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: SGSpacing.md) {
                if flow.steps.count > 1 {
                    PaywallStepIndicator(flow: flow, current: step)
                }
                cta()
            }
            .padding(.horizontal, SGSpacing.xl)
            .padding(.top, SGSpacing.md)
            .padding(.bottom, SGSpacing.sm)
            // Material resolves from the system appearance and was the last
            // light-gray strip in the dark paywall. This fixed stage surface keeps
            // the purchase controls visually continuous with the screen beneath.
            .background(SGT.surface)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(SGT.accentSecondary.opacity(0.32))
                    .frame(height: 1)
            }
        }
    }

    static var background: Color {
        SGT.background
    }
}

private struct PaywallStepIndicator: View {
    let flow: PaywallFlow
    let current: PaywallStep

    var body: some View {
        HStack(spacing: SGSpacing.xs) {
            ForEach(flow.steps, id: \.self) { step in
                Circle()
                    .fill(step == current ? SGT.ink : SGT.rule)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A fallback screen shown instead of any step when an automatic reminder cannot
/// yet confirm someone is not already subscribed. It bypasses the step machinery
/// entirely: no purchase control exists anywhere outside `.plan`, so this state
/// never risks exposing one before the check clears (see §8 in the paywall
/// redesign dev-note).
struct PaywallStatusView: View {
    let onRetry: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            Spacer()
            Text("We couldn’t confirm your Pro status.")
                .font(SGFont.body(17))
                .foregroundStyle(SGT.ink)
            Text("Check your connection before choosing a plan. If you already purchased Pro, restore it first.")
                .font(SGFont.caption(13))
                .foregroundStyle(SGT.ink2)
            Button("Try again", action: onRetry)
                .buttonStyle(SkyPrimaryButtonStyle())
            Button("Restore purchases", action: onRestore)
                .buttonStyle(SkySecondaryButtonStyle())
            Spacer()
        }
        .padding(SGSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(PaywallStepScaffold<EmptyView, EmptyView>.background.ignoresSafeArea())
    }
}

struct PaywallBenefit: View {
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

enum PaywallLegal {
    static let termsURL = SkyGridWeb.termsURL
    static let privacyURL: URL? = SkyGridWeb.privacyURL
}

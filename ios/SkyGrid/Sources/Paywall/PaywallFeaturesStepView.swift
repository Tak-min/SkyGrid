import SwiftUI

/// Step 2 (or step 1 for the automatic reminders, via `showsHeadline`): the
/// archive benefits, still with no price shown.
struct PaywallFeaturesStepView: View {
    let flow: PaywallFlow
    let entryPoint: PaywallEntryPoint
    /// True only when this step is the flow's first (`.ritualMilestone` or
    /// `.firstUnlock`), since those entry points never reach
    /// `PaywallValueStepView` and would otherwise never show
    /// `entryPoint.headline` at all.
    let showsHeadline: Bool
    let onAdvance: () -> Void
    let onContinueWithFree: () -> Void
    @State private var didRecordPreview = false

    var body: some View {
        PaywallStepScaffold(flow: flow, step: .features) {
            if showsHeadline {
                Text(entryPoint.headline)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(SGT.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ArchiveGrowthPreview {
                guard !didRecordPreview else { return }
                didRecordPreview = true
                PaywallAnalytics.record(.valuePreviewCompleted, entryPoint: entryPoint, step: .features)
            }
            benefits
            freeChoice
        } cta: {
            Button(action: onAdvance) {
                Text("See plans and pricing")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SkyPrimaryButtonStyle())

            Button("Continue with Free", action: onContinueWithFree)
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            let firstArchiveBenefit = entryPoint.firstArchiveBenefit
            PaywallBenefit(
                symbol: "calendar",
                title: firstArchiveBenefit.title,
                detail: firstArchiveBenefit.detail
            )
            PaywallBenefit(
                symbol: "square.grid.3x3",
                title: "Browse a month at a time",
                detail: "See the photos behind every season, not a colour substitute."
            )
            PaywallBenefit(
                symbol: "person.3.fill",
                title: "Grow an unlimited Circle",
                detail: "Keep as many buddies as you like instead of Free's 5."
            )
            PaywallBenefit(
                symbol: "rectangle.split.2x1.fill",
                title: "Put two skies side by side",
                detail: "Open and share a together card after you and a buddy both capture."
            )
            PaywallBenefit(
                symbol: "rectangle.stack.fill",
                title: "Relive every complete week",
                detail: "Turn seven mornings into a weekly recap you can share."
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

    private var freeChoice: some View {
        HStack(alignment: .top, spacing: SGSpacing.sm) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(SGT.ink2)
            Text("Free includes daily capture, the recent archive, and a 5-person Circle. Pro opens the full archive, month view, an unlimited Circle, together cards, and weekly recaps.")
                .font(SGFont.caption(13))
                .foregroundStyle(SGT.ink2)
        }
        .padding(.horizontal, SGSpacing.sm)
    }
}

/// A short, replayable demonstration of the archive's actual value progression.
/// It uses illustrative tiles rather than invented photos and never delays the
/// pricing CTA. Reduce Motion lands directly on the final state.
private struct ArchiveGrowthPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0
    let onCompleted: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        Button(action: replay) {
            VStack(spacing: SGSpacing.md) {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(0..<49, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(tileColor(index))
                            .aspectRatio(1, contentMode: .fit)
                            .scaleEffect(index < filledCount ? 1 : 0.72)
                            .opacity(index < filledCount ? 1 : 0.24)
                            .skyAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.78), value: filledCount)
                    }
                }
                .frame(maxWidth: 196)

                HStack {
                    Text(stageLabel)
                        .font(SGFont.body(15))
                        .foregroundStyle(SGT.ink)
                        .contentTransition(.numericText())
                    Spacer()
                    Label("Replay", systemImage: "arrow.counterclockwise")
                        .font(SGFont.caption(12))
                        .foregroundStyle(SGT.ink3)
                }
            }
            .padding(SGSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(SGT.fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: L10n.string("paywall.archiveGrowthPreviewAccessibility"), stageLabel))
        .accessibilityHint("Replays the seven day, thirty day, and one year preview")
        .task { await play() }
    }

    private var filledCount: Int {
        switch phase {
        case 0: 7
        case 1: 24
        default: 49
        }
    }

    // Routed through `L10n.string(_:)`: `Text(stageLabel)` consumes this as a
    // stored `String` property, not a `Text("literal")` call site (see
    // `dev-notes/localization-en-ja-stage2_*.md`).
    private var stageLabel: String {
        switch phase {
        case 0: L10n.string("paywall.features.stage.first7Mornings")
        case 1: L10n.string("paywall.features.stage.monthTakesShape")
        default: L10n.string("paywall.features.stage.yearBecomesLandscape")
        }
    }

    private func tileColor(_ index: Int) -> Color {
        guard index < filledCount else { return SGT.rule }
        if index.isMultiple(of: 5) { return SGT.accent }
        if index.isMultiple(of: 3) { return SGT.accentSecondary }
        return SGT.ink.opacity(0.78)
    }

    private func replay() {
        Task { await play() }
    }

    @MainActor
    private func play() async {
        if reduceMotion {
            phase = 2
            onCompleted()
            return
        }
        withAnimation(.easeOut(duration: 0.18)) { phase = 0 }
        try? await Task.sleep(for: .milliseconds(1_100))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { phase = 1 }
        try? await Task.sleep(for: .milliseconds(1_400))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) { phase = 2 }
        onCompleted()
    }
}

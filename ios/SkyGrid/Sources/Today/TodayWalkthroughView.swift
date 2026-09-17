import SwiftUI

/// A first-visit coach layer rendered over the real Today screen. It has no skip
/// gesture or skip button; Back remains available after the first explanation.
struct TodayWalkthroughView: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    private var pages: [TodayWalkthroughPage] {
        [
            .init(icon: "camera.fill", eyebrow: L10n.string("today.walkthrough.morning.eyebrow"), title: L10n.string("today.walkthrough.morning.title"), detail: L10n.string("today.walkthrough.morning.detail"), alignment: .bottom),
            .init(icon: "person.2.fill", eyebrow: L10n.string("today.walkthrough.buddy.eyebrow"), title: L10n.string("today.walkthrough.buddy.title"), detail: L10n.string("today.walkthrough.buddy.detail"), alignment: .top),
            .init(icon: "square.grid.3x3.fill", eyebrow: L10n.string("today.walkthrough.mosaic.eyebrow"), title: L10n.string("today.walkthrough.mosaic.title"), detail: L10n.string("today.walkthrough.mosaic.detail"), alignment: .bottom),
            .init(icon: "sparkles", eyebrow: L10n.string("today.walkthrough.moku.eyebrow"), title: L10n.string("today.walkthrough.moku.title"), detail: L10n.string("today.walkthrough.moku.detail"), alignment: .top),
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.38).ignoresSafeArea()
                VStack(spacing: 0) {
                    if pages[step].alignment == .bottom { Spacer(minLength: proxy.size.height * 0.36) }
                    coachCard
                    if pages[step].alignment == .top { Spacer(minLength: proxy.size.height * 0.36) }
                }
                .padding(.horizontal, SGSpacing.lg)
                .padding(.vertical, SGSpacing.xl)
            }
        }
        .accessibilityIdentifier("today.walkthrough")
    }

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            HStack {
                Label(pages[step].eyebrow, systemImage: pages[step].icon)
                    .font(SGFont.caption(11))
                    .tracking(1.4)
                    .foregroundStyle(SGT.accentSecondary)
                Spacer()
                Text("\(step + 1) / \(pages.count)")
                    .font(SGFont.numeric(12, weight: .medium))
                    .foregroundStyle(MokuColor.cloud.opacity(0.58))
            }
            HStack(alignment: .top, spacing: SGSpacing.md) {
                MokuView(state: step == pages.count - 1 ? .delight : .ready, side: 70)
                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    Text(pages[step].title)
                        .font(SGFont.title(23))
                        .foregroundStyle(MokuColor.cloud)
                    Text(pages[step].detail)
                        .font(SGFont.body(15))
                        .foregroundStyle(MokuColor.cloud.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: SGSpacing.md) {
                if step > 0 {
                    Button(L10n.string("Back")) { move(to: step - 1) }
                        .buttonStyle(SkySecondaryButtonStyle())
                        .frame(width: 92)
                }
                Button(L10n.string(step == pages.count - 1 ? "today.walkthrough.start" : "Next")) {
                    if step == pages.count - 1 { onComplete() }
                    else { move(to: step + 1) }
                }
                .buttonStyle(SkyPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(SGSpacing.lg)
        .background(MokuColor.nightStage.opacity(0.98), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 28, y: 12)
        .id(step)
        .transition(reduceMotion ? .opacity : .scale(scale: 0.97).combined(with: .opacity))
    }

    private func move(to newStep: Int) {
        guard pages.indices.contains(newStep) else { return }
        if reduceMotion || !MokuMotionPolicy.animationsEnabled { step = newStep }
        else { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { step = newStep } }
    }
}

private struct TodayWalkthroughPage {
    enum Alignment { case top, bottom }
    let icon: String
    let eyebrow: String
    let title: String
    let detail: String
    let alignment: Alignment
}

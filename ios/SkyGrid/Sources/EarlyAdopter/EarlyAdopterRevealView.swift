import SwiftUI
import UIKit

/// A one-time celebratory reveal for early adopters who have been granted 60 days of Pro.
/// Styled to match the existing MilestoneView and RewardOverlayView visual language.
struct EarlyAdopterRevealView: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            PlayfulStageBackdrop(accent: SGT.accent)

            VStack(spacing: SGSpacing.xl) {
                headline
                content
                dismissButton
                Spacer()
            }
            .padding(.horizontal, SGSpacing.xl)
            .padding(.vertical, SGSpacing.xxl)
        }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.94)
        .task {
            Haptics.rewardLanded()
            SoundEffectPlayer.shared.play(.purchaseConfirmed)
            // Reduce Motion still gets the state change, just without the spring animation.
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(SGMotion.settle) { hasAppeared = true }
            }
        }
    }

    private var headline: some View {
        VStack(spacing: SGSpacing.sm) {
            Text(L10n.string("earlyAdopter.reveal.title"))
                .font(SGFont.display(48))
                .foregroundStyle(SGT.ink)
            Text(L10n.string("earlyAdopter.reveal.subtitle"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(SGT.ink2)
                .lineLimit(3)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.string("earlyAdopter.reveal.title")). \(L10n.string("earlyAdopter.reveal.subtitle"))")
    }

    private var content: some View {
        VStack(spacing: SGSpacing.lg) {
            Image(systemName: "star.fill")
                .font(.system(size: 52))
                .foregroundStyle(SGT.accent)

            Text(L10n.string("earlyAdopter.reveal.body"))
                .font(SGFont.body(16))
                .foregroundStyle(SGT.ink2)
                .multilineTextAlignment(.center)
                .lineLimit(4)
        }
    }

    private var dismissButton: some View {
        Button(L10n.string("earlyAdopter.reveal.dismiss")) {
            onDone()
        }
        .buttonStyle(SkyPrimaryButtonStyle())
    }
}

#if DEBUG
#Preview {
    EarlyAdopterRevealView(onDone: {})
}
#endif

import SwiftUI

struct WelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                OnboardingProgress(step: 1, total: 9)
                MokuWelcomeStage()
                VStack(alignment: .leading, spacing: SGSpacing.md) {
                    Text("Keep one\nmorning sky.")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(SGT.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Meet Moku, your little morning companion. Take one sky photo. Watch your year take shape.")
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(SGSpacing.xl)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: SGSpacing.sm) {
                Button(action: onNext) {
                    HStack {
                        Text("Get started")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SkyPrimaryButtonStyle())
                .accessibilityIdentifier("onboarding.getStarted")
                Text("A little sky. A morning that's yours.")
                    .font(SGFont.caption(12))
                    .foregroundStyle(SGT.ink3)
            }
            .padding(.horizontal, SGSpacing.xl)
            .padding(.vertical, SGSpacing.md)
            .background(SGT.background)
        }
        .background(PlayfulStageBackdrop())
    }
}

/// The mosaic is a stationary floor; Moku alone steps out of its plane. The
/// optional toy has a separate hit target and never gates the primary action.
private struct MokuWelcomeStage: View {
    @State private var interaction = 0
    @State private var lastInteraction: TimeInterval = -.infinity

    var body: some View {
        VStack(spacing: SGSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .fill(SGT.accentSecondary.opacity(0.09))
                    .frame(width: 238, height: 194)
                    .rotationEffect(.degrees(-8))
                    .offset(y: 22)

                RitualGridMark(side: 194)
                    .rotation3DEffect(.degrees(56), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                    .rotationEffect(.degrees(-8))
                    .offset(y: 71)

                Button {
                    let now = ProcessInfo.processInfo.systemUptime
                    guard now - lastInteraction >= 1.15 else { return }
                    lastInteraction = now
                    interaction += 1
                } label: {
                    MokuView(state: .ready, side: 144, interaction: interaction, leapsOnArrival: true)
                        .frame(width: 190, height: 198)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(y: -16)
                .accessibilityLabel("Say hello to Moku")
                .accessibilityHint("Moku says hello back. You can get started at any time.")
                .accessibilityIdentifier("moku.play")
            }
            .frame(maxWidth: .infinity)
            // The 3D-rotated mosaic's near edge projects below its layout bounds,
            // so a height that merely fits the untransformed art let the caption
            // collide with the front tile rows — illegible in dark mode, where
            // both are low-contrast greys. Reserve the projected depth instead.
            .frame(height: 286)
            Text("Tap Moku to say hello")
                .font(SGFont.caption(12))
                .foregroundStyle(SGT.ink3)
        }
    }
}

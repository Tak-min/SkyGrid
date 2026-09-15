import SwiftUI

struct WelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                OnboardingProgress(step: 2, total: 10)
                MokuWelcomeStage()
                VStack(alignment: .leading, spacing: SGSpacing.md) {
                    Text("Keep one\nmorning sky.")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(SGT.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.string("welcome.moku.introduction"))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var interaction = 0
    @State private var dialogueStep = 0
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
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        dialogueStep = (dialogueStep + 1) % 2
                    }
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

                Text(dialogueLine)
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, SGSpacing.md)
                    .padding(.vertical, SGSpacing.sm)
                    .frame(width: 178, alignment: .leading)
                    .background(SGT.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(SGT.rule, lineWidth: 1)
                    }
                    .offset(x: 58, y: -96)
                    .id(dialogueStep)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .accessibilityIdentifier("onboarding.mokuDialogue")
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
        .task {
            guard !reduceMotion else {
                dialogueStep = 1
                return
            }
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                dialogueStep = 1
            }
        }
    }

    private var dialogueLine: String {
        dialogueStep == 0
            ? L10n.string("welcome.moku.dialogue.introduction")
            : "Six quick questions, then we'll shape your morning. Ready?"
    }
}

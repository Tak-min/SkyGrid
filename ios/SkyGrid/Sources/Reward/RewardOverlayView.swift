import SwiftUI

/// The bounded, at-most-once-per-day celebration for a successful capture —
/// DESIGN.md's "Daily reward motion contract". Plays Moku's bracing → delight →
/// settled arc, one confetti burst at the reward-peak beat, and one success haptic;
/// dismisses itself on completion via `onDone`.
///
/// Beats `.pixelDerivation` and `.mosaicLanding` are timed here but render nothing
/// of their own yet — the real photo-to-pixel-tile transform and mosaic landing
/// motion are VISION.md Iteration 5's job. This view only owns the parts DESIGN.md
/// assigns to Iteration 4: the state machine, the reward-peak confetti/haptic, the
/// completion analytics, and Reduce Motion parity.
struct RewardOverlayView: View {
    let moment: RewardMoment
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controller: RewardSequenceController?

    var body: some View {
        ZStack {
            RewardStageColor.background.ignoresSafeArea()

            if let controller {
                content(controller: controller)
            }
        }
        .task {
            let controller = RewardSequenceController(reducedMotion: reduceMotion)
            self.controller = controller
            controller.start(onComplete: onDone)
        }
        .onDisappear {
            // A view recreation or backgrounding mid-sequence must resolve to the
            // truthful settled state without replaying the reward or claiming a
            // completion that never happened — DESIGN.md's interruption rule.
            controller?.cancel()
        }
    }

    @ViewBuilder
    private func content(controller: RewardSequenceController) -> some View {
        let beat = controller.beat
        VStack(spacing: SGSpacing.xl) {
            Spacer()
            ZStack {
                if beat == .rewardPeak, !reduceMotion {
                    ConfettiView(
                        palette: [
                            moment.skyColor.color,
                            MokuColor.dawnSpark,
                            MokuColor.cloud
                        ],
                        seed: UInt64(bitPattern: Int64(moment.localDate.docID.hashValue))
                    )
                    .frame(width: 220, height: 220)
                }
                if reduceMotion, beat != .settle {
                    // The Reduce Motion equivalent of confetti: a static halo, not a
                    // moving burst, shown for up to 500 ms per DESIGN.md.
                    Circle()
                        .fill(moment.skyColor.color.opacity(0.35))
                        .frame(width: 160, height: 160)
                }
                MokuView(state: mokuState(for: beat), side: 128, capturedSkyPalette: [moment.skyColor.color])
            }
            .frame(height: 220)
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityAnnouncement(for: beat))
    }

    private func mokuState(for beat: RewardBeat) -> MokuState {
        switch beat {
        case .captureConfirmation: .bracing
        case .pixelDerivation, .mosaicLanding: .bracing
        case .rewardPeak: .delight
        case .settle: .settled
        }
    }

    /// One concise VoiceOver result once settlement is reached, per DESIGN.md's
    /// accessibility section. Buddy-reveal count is not yet wired to this overlay
    /// (VISION.md Iteration 7), so this only announces the capture-saved result for
    /// now — no buddy count is claimed here that this view cannot yet verify.
    private func accessibilityAnnouncement(for beat: RewardBeat) -> String {
        beat == .settle ? "Sky saved." : ""
    }
}

private enum RewardStageColor {
    static let background = Color(red: 8 / 255, green: 10 / 255, blue: 15 / 255)
}

import SwiftUI
import UIKit

/// The bounded, at-most-once-per-day celebration for a successful capture —
/// DESIGN.md's "Daily reward motion contract". Plays Moku's bracing → delight →
/// settled arc, one confetti burst at the reward-peak beat, and one success haptic;
/// dismisses itself on completion via `onDone`.
///
/// The real local thumbnail visibly resolves into a 24×24 derived tile and lands in
/// its date-derived mosaic slot before the reward peak. The original is not changed
/// or exposed beyond this already-authorized, post-publish local reward surface.
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
        VStack(spacing: SGSpacing.lg) {
            ZStack {
                RewardMosaicLandingView(
                    sourceThumbnail: moment.thumbnailData.flatMap(UIImage.init(data:)),
                    tile: PixelSkyTileRenderer.makeTile(from: moment.thumbnailData),
                    fallbackColor: moment.skyColor.color,
                    localDate: moment.localDate,
                    beat: beat
                )
                .frame(width: 252, height: 250)

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
                    .offset(y: 116)
            }
            .frame(height: 310)
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

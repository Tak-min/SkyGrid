import Foundation
import Observation

/// Drives one playback of the daily reward's beat timeline (`RewardBeat`) and fires
/// each state's one-shot side effect exactly once: the reward-started analytics
/// event, the reward-peak haptic, and the reward-completed analytics event.
///
/// Owns no view. `RewardOverlayView` reads `beat` to decide what to render; this
/// class only owns time and the side effects that must happen exactly once
/// regardless of how many times SwiftUI re-evaluates the view body.
@MainActor
@Observable
final class RewardSequenceController {
    private(set) var beat: RewardBeat = .captureConfirmation
    private(set) var isFinished = false

    private let reducedMotion: Bool
    private var playbackTask: Task<Void, Never>?
    private var completion: (() -> Void)?

    init(reducedMotion: Bool) {
        self.reducedMotion = reducedMotion
    }

    /// Starts (or restarts) the timeline. Safe to call from `.task` on the owning
    /// view — cancelling any previous playback first means a view re-appearance
    /// can never leave two timelines racing to fire `onComplete` twice.
    func start(onComplete: @escaping () -> Void) {
        guard playbackTask == nil, !isFinished else { return }
        completion = onComplete
        playbackTask?.cancel()
        beat = .captureConfirmation
        isFinished = false

        playbackTask = Task { [reducedMotion] in
            RewardAnalytics.record(.rewardStarted, reducedMotion: reducedMotion)

            if reducedMotion {
                // Per DESIGN.md's Reduce Motion section: one short transition
                // straight to the settled state, not the full spatial timeline.
                try? await Task.sleep(for: .seconds(RewardBeat.reducedMotionDuration))
                guard !Task.isCancelled else { return }
                Haptics.rewardLanded()
                beat = .settle
            } else {
                var elapsed: TimeInterval = 0
                for nextBeat in RewardBeat.allCases where nextBeat != .captureConfirmation {
                    let wait = nextBeat.startOffset - elapsed
                    if wait > 0 {
                        try? await Task.sleep(for: .seconds(wait))
                    }
                    guard !Task.isCancelled else { return }
                    elapsed = nextBeat.startOffset
                    beat = nextBeat
                    if nextBeat == .rewardPeak {
                        Haptics.rewardLanded()
                    }
                }
                let remaining = RewardBeat.totalDuration - elapsed
                if remaining > 0 {
                    try? await Task.sleep(for: .seconds(remaining))
                }
                guard !Task.isCancelled else { return }
            }

            // Leave the settled mosaic and its VoiceOver result on screen long
            // enough to be rendered/read before its cover closes. The normal path
            // uses a shorter linger than Reduce Motion's so that
            // RewardBeat.totalDuration + this linger stays under DESIGN.md's
            // "completes in under 1.8 seconds in the normal path" contract
            // (1.6s + 0.15s = 1.75s); Reduce Motion's own path has no such budget
            // and keeps the original, longer linger since its settled state is
            // reached much sooner (0.2s) and its VoiceOver announcement deserves
            // the same reading time it always had.
            let postSettleLinger: TimeInterval = reducedMotion ? 0.4 : 0.15
            try? await Task.sleep(for: .seconds(postSettleLinger))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    /// Stops playback without firing `onComplete` — used when the owning view
    /// disappears mid-sequence (e.g. the app is backgrounded), so a cancelled
    /// timeline can never claim it completed.
    func cancel() {
        playbackTask?.cancel()
        playbackTask = nil
        // An interrupted reward never restarts from a capture confirmation. Its
        // only truthful next state is the already-earned settled result.
        beat = .settle
        isFinished = true
    }

    private func finish() {
        guard !isFinished else { return }
        RewardAnalytics.record(.rewardCompleted, reducedMotion: reducedMotion)
        isFinished = true
        completion?()
    }
}

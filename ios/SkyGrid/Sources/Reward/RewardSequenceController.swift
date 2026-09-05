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

    init(reducedMotion: Bool) {
        self.reducedMotion = reducedMotion
    }

    /// Starts (or restarts) the timeline. Safe to call from `.task` on the owning
    /// view — cancelling any previous playback first means a view re-appearance
    /// can never leave two timelines racing to fire `onComplete` twice.
    func start(onComplete: @escaping () -> Void) {
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

            RewardAnalytics.record(.rewardCompleted, reducedMotion: reducedMotion)
            isFinished = true
            onComplete()
        }
    }

    /// Stops playback without firing `onComplete` — used when the owning view
    /// disappears mid-sequence (e.g. the app is backgrounded), so a cancelled
    /// timeline can never claim it completed.
    func cancel() {
        playbackTask?.cancel()
        playbackTask = nil
    }
}

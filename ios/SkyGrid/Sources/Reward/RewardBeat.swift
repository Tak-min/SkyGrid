import Foundation

/// The five causal beats of the daily reward, per DESIGN.md's "Daily reward motion
/// contract" table.
///
/// Beats `.pixelDerivation` and `.mosaicLanding` are sequenced here so the whole
/// timeline already has the right causal order and duration — but this iteration
/// (VISION.md Iteration 4) only owns the state machine, the reward-peak
/// confetti/haptic, and Reduce Motion parity. Their real photo-to-tile visual
/// transform is Iteration 5's job; until then those two beats pass through with no
/// content of their own, deliberately not with placeholder tile art that a later
/// diff would otherwise need to delete.
enum RewardBeat: Equatable, CaseIterable {
    case captureConfirmation
    case pixelDerivation
    case mosaicLanding
    case rewardPeak
    case settle

    /// Elapsed time, from reward start, at which this beat becomes current. Matches
    /// the lower bound of each beat's target window in DESIGN.md's contract table.
    var startOffset: TimeInterval {
        switch self {
        case .captureConfirmation: 0
        case .pixelDerivation: 0.18
        case .mosaicLanding: 0.56
        case .rewardPeak: 0.9
        case .settle: 1.35
        }
    }

    /// The full normal-path sequence completes here — inside DESIGN.md's 1.4-1.8
    /// second target window.
    static let totalDuration: TimeInterval = 1.6

    /// Reduce Motion replaces the whole spatial sequence with one short transition
    /// straight to the settled state, per DESIGN.md's "Reduce Motion and
    /// accessibility" section.
    static let reducedMotionDuration: TimeInterval = 0.2

    /// The beat that is current at `elapsed` seconds into the normal-path sequence.
    /// Clamped implicitly: any `elapsed` before the first beat's offset (0) still
    /// resolves to `.captureConfirmation`, and any `elapsed` at or past `.settle`'s
    /// offset stays `.settle`.
    static func current(atElapsed elapsed: TimeInterval) -> RewardBeat {
        allCases.reversed().first { elapsed >= $0.startOffset } ?? .captureConfirmation
    }
}

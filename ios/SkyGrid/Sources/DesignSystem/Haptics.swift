import UIKit

/// Deliberately minimal, and split along the same calm/loud boundary as
/// `SGT` vs `SGExport`: the morning ritual gets one soft pulse and nothing else,
/// while the milestone moment — which is an explicit celebration — gets a success
/// notification.
///
/// This supersedes the earlier rule that `postCompleted` was the ONLY haptic in the
/// app (and VISION.md §6's blanket ban on level-up effects). The persona change to a
/// shareable, milestone-driven product was a deliberate product decision; see
/// `dev-notes/ui-viral-persona-pass_2026-08-08.md`. Both are still bounded: two
/// haptics total, neither of them during capture.
enum Haptics {
    static func postCompleted() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    /// Fires only from `MilestoneView`, at a streak threshold — at most a handful of
    /// times in a user's life, never on an ordinary morning.
    static func milestoneReached() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

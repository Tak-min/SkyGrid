import UIKit

/// Deliberately minimal, and split along the same calm/loud boundary as
/// `SGT` vs `SGExport`: the morning ritual gets one soft pulse and nothing else,
/// while the milestone moment — which is an explicit celebration — gets a success
/// notification.
///
/// This supersedes the earlier rule that `postCompleted` was the ONLY haptic in the
/// app (and VISION.md §6's blanket ban on level-up effects). The persona change to a
/// shareable, milestone-driven product was a deliberate product decision; see
/// `dev-notes/ui-viral-persona-pass_2026-08-08.md`.
///
/// The 2026-09-05 playful-reward redesign (DESIGN.md's "Daily reward motion
/// contract") adds one more: `rewardLanded`, at the reward peak beat. That contract
/// is explicit that button-press feedback (`postCompleted`'s soft impact, fired at
/// capture confirm) and a "success" notification haptic must never stack — so
/// `rewardLanded` is a distinct, later beat rather than a second call alongside
/// `postCompleted`.
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

    /// Fires once, at the daily reward's reward-peak beat — DESIGN.md's "one success
    /// haptic occurs at landing" rule. Never called alongside `postCompleted` for the
    /// same capture; see the type-level note above.
    static func rewardLanded() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

import UIKit

/// Deliberately minimal: Sky Grid's tone is quiet and non-celebratory (VISION.md §6
/// explicitly rules out success chimes, confetti, and level-up effects). The ONLY
/// haptic in the app is a single soft pulse when a post finishes — nowhere else.
enum Haptics {
    static func postCompleted() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }
}

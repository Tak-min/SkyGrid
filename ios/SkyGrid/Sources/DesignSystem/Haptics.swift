import UIKit

/// One feedback budget across navigation, character play, and the saved-capture
/// reward. Generators survive individual taps; overlapping callbacks cannot stack
/// motors or manufacture an extra success notification.
@MainActor
enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let landing = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()
    private static var lastFeedbackTime: TimeInterval = -.infinity
    private static var lastSuccessTime: TimeInterval = -.infinity

    /// Reduce Motion deliberately does NOT gate this. Haptics are not motion, and
    /// suppressing them there would silently drop the shipped `postCompleted`
    /// confirmation for exactly the people who lost the animation that carried the
    /// same meaning. Character-play haptics stay tied to motion at their own call
    /// site in `MokuView`, which is where that coupling belongs.
    private static var enabled: Bool {
        UIApplication.shared.applicationState == .active
            && !ProcessInfo.processInfo.arguments.contains("-SkyGridUIAudit")
    }

    private static func accept(minimumInterval: TimeInterval = 0.09) -> Bool {
        guard enabled else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFeedbackTime >= minimumInterval else { return false }
        lastFeedbackTime = now
        return true
    }

    static func selectionChanged() {
        guard accept() else { return }
        selection.selectionChanged()
    }

    static func navigationConfirmed() {
        guard accept(minimumInterval: 0.12) else { return }
        soft.impactOccurred(intensity: 0.55)
    }

    static func characterTouched() {
        guard accept(minimumInterval: 0.16) else { return }
        soft.impactOccurred(intensity: 0.45)
        landing.prepare()
    }

    static func characterLanded() {
        guard accept(minimumInterval: 0.16) else { return }
        landing.impactOccurred(intensity: 0.45)
    }

    /// Tactile capture confirmation, distinct from durable-save success.
    static func postCompleted() {
        guard accept(minimumInterval: 0.16) else { return }
        soft.impactOccurred(intensity: 0.7)
    }

    static func milestoneReached() { success() }
    static func rewardLanded() { success() }

    private static func success() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSuccessTime >= 1.2, accept(minimumInterval: 0.25) else { return }
        lastSuccessTime = now
        notification.notificationOccurred(.success)
    }
}

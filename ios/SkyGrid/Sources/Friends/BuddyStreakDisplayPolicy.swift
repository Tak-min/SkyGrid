import Foundation

/// Pure rendering policy for the pair-level streak. Its narrow freshness window is
/// intentional: a stale value is silence, never a "broken" message or evidence of
/// which member missed a morning.
enum BuddyStreakDisplayPolicy {
    struct Display: Equatable, Sendable {
        let text: String
        let accessibilityLabel: String
    }

    static func display(
        current: Int?,
        lastMutualDate: LocalDate?,
        today: LocalDate,
        buddyName: String
    ) -> Display? {
        guard let current, current > 0,
              let lastMutualDate,
              lastMutualDate == today || lastMutualDate == today.adding(days: -1)
        else { return nil }

        let dayWord = current == 1 ? "day" : "days"
        return Display(
            text: "Together \(current) \(dayWord)",
            accessibilityLabel: "\(current) consecutive \(current == 1 ? "morning" : "mornings") with \(buddyName)"
        )
    }
}

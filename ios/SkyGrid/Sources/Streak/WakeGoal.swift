import Foundation

/// A user's target wake time, stored as minutes after local midnight
/// (`users/{uid}.wakeGoalMinutes`).
struct WakeGoal: Sendable {
    let minutesAfterMidnight: Int

    /// Positive = later than goal, negative = earlier than goal. Powers the
    /// A "Captured 6:42 / Posted 9:10" readout and `SkyPost.minutesFromGoalDescription`.
    func minutesFromGoal(capturedAt: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: capturedAt)
        let actualMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return actualMinutes - minutesAfterMidnight
    }
}

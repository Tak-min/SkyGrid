import Foundation

/// VISION.md §3, pain point #3: even on the free tier, one missed morning per week
/// doesn't have to break the chain — this is the policy `StreakCalculator`'s
/// `exemptDays` gets fed from (in addition to timezone-change days).
enum RestDayPolicy {
    static let freeRestDaysPerWeek = 1

    /// Whether a rest day can still be granted for the current 7-day window, given
    /// how many have already been used in it.
    static func hasRestDayAvailable(usedRestDaysThisWeek: Int, isPro: Bool) -> Bool {
        isPro || usedRestDaysThisWeek < freeRestDaysPerWeek
    }
}

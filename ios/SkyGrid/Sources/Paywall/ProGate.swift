import Foundation

/// Pure gating logic — kept separate from pricing/UI so it can be written and tested
/// even while the actual tier structure (VISION.md §2) is still undecided.
enum ProGate {
    static let freeArchiveWindowDays = 30

    /// Whether `date` is within the free tier's visible archive window, measured
    /// from `today`.
    static func isWithinFreeArchiveWindow(_ date: LocalDate, today: LocalDate) -> Bool {
        date <= today && date.daysUntil(today) <= freeArchiveWindowDays
    }

    static func canViewFullYearGrid(isPro: Bool) -> Bool {
        isPro
    }
}

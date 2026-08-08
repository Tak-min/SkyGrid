import Foundation
import Observation

/// One snapshot of the history listener, as observed by the *only* thing that
/// computes the streak.
///
/// The streak and the post are carried together on purpose: they come from the same
/// `observePosts` emission, so a milestone card and the number on Today are the same
/// evaluation of `StreakCalculator.summarize` rather than two evaluations that merely
/// ought to agree. A separate consumer-side recount — even calling the identical pure
/// function — would read a *different* snapshot and could print 6 while Today prints 7.
enum StreakReading: Equatable, Sendable {
    /// The history read failed. Published explicitly rather than skipped so that
    /// "never celebrate from a failed read" is a branch a test can pin down, instead
    /// of an accident of control flow.
    case unavailable(localDate: LocalDate)
    case observed(localDate: LocalDate, summary: StreakSummary, post: SkyPost?)

    var localDate: LocalDate {
        switch self {
        case .unavailable(let localDate): return localDate
        case .observed(let localDate, _, _): return localDate
        }
    }
}

/// A one-way channel from the streak's single producer (`TodayViewModel`) up to
/// `RootView`, which owns post-capture moment arbitration but has no reference to the
/// view model (`TodayView` captures it as `@State`).
///
/// Deliberately not a second source of truth: it stores what the producer already
/// computed and never derives anything itself.
@MainActor
@Observable
final class StreakSignal {
    private(set) var reading: StreakReading?

    /// No-ops on an equal value. The history listener re-emits the same snapshot
    /// routinely, and a silent write would re-fire every `onChange` observer for no
    /// state change.
    func record(_ reading: StreakReading) {
        guard self.reading != reading else { return }
        self.reading = reading
    }
}

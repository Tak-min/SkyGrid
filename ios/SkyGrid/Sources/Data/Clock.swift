import Foundation

/// The single injection point for "what time is it / what timezone am I in" — every
/// date/timezone-dependent computation in the app goes through this, never
/// `Date()`/`TimeZone.current` directly, so tests can be deterministic (blueprint
/// §3.3) and so `TimeZoneWatcher` has one place to observe.
protocol Clock: Sendable {
    var now: Date { get }
    var timeZone: TimeZone { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
    var timeZone: TimeZone { .current }
}

/// Test/preview double with a fixed instant and zone.
struct FixedClock: Clock {
    let now: Date
    let timeZone: TimeZone

    init(now: Date, timeZone: TimeZone = TimeZone(identifier: "UTC")!) {
        self.now = now
        self.timeZone = timeZone
    }
}

extension Clock {
    func today() -> LocalDate { LocalDate(date: now, timeZone: timeZone) }
}

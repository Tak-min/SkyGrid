import Foundation

/// A calendar day, independent of time-of-day or the device's current locale/calendar
/// settings. This is the single source of truth for the `YYYY-MM-DD` Firestore
/// document ID — no other type in this codebase should format a `Date` into that
/// shape, because a device set to a non-Gregorian calendar (e.g. Japanese era) would
/// otherwise silently produce a broken document ID such as "R8-07-29".
struct LocalDate: Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    /// Pinned deliberately: this must never track the user's device locale/calendar,
    /// or `docID` stops being a stable `YYYY-MM-DD` string.
    private static let referenceCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Derives the calendar day for `date` as observed in `timeZone` — this is the
    /// only place "what day is it" should be computed from a `Date`.
    init(date: Date, timeZone: TimeZone) {
        var calendar = Self.referenceCalendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = components.year!
        self.month = components.month!
        self.day = components.day!
    }

    /// `YYYY-MM-DD`, always — the Firestore `posts/{localDate}` document ID.
    var docID: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Parses a `docID`-shaped string back into a `LocalDate`. Returns `nil` for any
    /// malformed input rather than trapping, since this is used to parse untrusted
    /// Firestore document IDs.
    init?(docID: String) {
        let parts = docID.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d)
        else { return nil }
        self.year = y
        self.month = m
        self.day = d
    }

    func adding(days: Int) -> LocalDate {
        let calendar = Self.referenceCalendar
        let base = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        let shifted = calendar.date(byAdding: .day, value: days, to: base)!
        return LocalDate(date: shifted, timeZone: TimeZone(identifier: "UTC")!)
    }

    /// Number of calendar days between two `LocalDate`s (`other - self`).
    func daysUntil(_ other: LocalDate) -> Int {
        let calendar = Self.referenceCalendar
        let start = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        let end = calendar.date(from: DateComponents(year: other.year, month: other.month, day: other.day))!
        return calendar.dateComponents([.day], from: start, to: end).day!
    }
}

extension LocalDate: Comparable {
    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension LocalDate: CustomStringConvertible {
    var description: String { docID }
}

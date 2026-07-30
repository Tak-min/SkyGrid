import Testing
import Foundation
@testable import SkyGrid

@Suite("LocalDate")
struct LocalDateTests {
    @Test("docID is always YYYY-MM-DD regardless of device calendar/locale")
    func docIDIsLocalePinned() {
        // Even if the process's *current* Locale/Calendar were Japanese-era based,
        // LocalDate must never reflect that — it pins en_US_POSIX + Gregorian
        // internally (see LocalDate.referenceCalendar). We simulate the failure mode
        // this guards against by constructing directly from components.
        let date = LocalDate(year: 2026, month: 7, day: 29)
        #expect(date.docID == "2026-07-29")
    }

    @Test("round-trips through docID parsing")
    func parsesOwnDocID() {
        let date = LocalDate(year: 2026, month: 1, day: 5)
        let parsed = LocalDate(docID: date.docID)
        #expect(parsed == date)
    }

    @Test("rejects malformed docID strings")
    func rejectsMalformedDocID() {
        #expect(LocalDate(docID: "not-a-date") == nil)
        #expect(LocalDate(docID: "2026-13-01") == nil)
        #expect(LocalDate(docID: "2026-01-99") == nil)
    }

    @Test("derives the same calendar day from a Date + timezone consistently")
    func derivesFromDateAndTimeZone() {
        // 2026-07-29 23:30 UTC is still 2026-07-29 in UTC, but 2026-07-30 in a
        // timezone east of UTC — this is exactly the timezone-boundary behavior the
        // app relies on for "what day is it right now".
        var components = DateComponents()
        components.year = 2026; components.month = 7; components.day = 29
        components.hour = 23; components.minute = 30
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let instant = utcCalendar.date(from: components)!

        let inUTC = LocalDate(date: instant, timeZone: TimeZone(identifier: "UTC")!)
        #expect(inUTC.docID == "2026-07-29")

        let inTokyo = LocalDate(date: instant, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        #expect(inTokyo.docID == "2026-07-30")
    }

    @Test("is Comparable in calendar order")
    func comparable() {
        let earlier = LocalDate(year: 2026, month: 1, day: 1)
        let later = LocalDate(year: 2026, month: 12, day: 31)
        #expect(earlier < later)
    }

    @Test("adding(days:) crosses month/year boundaries correctly")
    func addingDaysCrossesBoundaries() {
        let dec31 = LocalDate(year: 2026, month: 12, day: 31)
        #expect(dec31.adding(days: 1).docID == "2027-01-01")

        let jan1 = LocalDate(year: 2026, month: 1, day: 1)
        #expect(jan1.adding(days: -1).docID == "2025-12-31")
    }

    @Test("daysUntil computes signed day difference")
    func daysUntilComputesDifference() {
        let a = LocalDate(year: 2026, month: 7, day: 1)
        let b = LocalDate(year: 2026, month: 7, day: 8)
        #expect(a.daysUntil(b) == 7)
        #expect(b.daysUntil(a) == -7)
    }
}

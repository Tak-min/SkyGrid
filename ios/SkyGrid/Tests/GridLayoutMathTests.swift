import Testing
import CoreGraphics
@testable import SkyGrid

@Suite("GridLayoutMath")
struct GridLayoutMathTests {
    @Test("2026 is not a leap year: Feb has 28 days")
    func nonLeapFebruary() {
        #expect(GridLayoutMath.daysInMonth(month: 2, year: 2026) == 28)
    }

    @Test("2028 is a leap year: Feb has 29 days")
    func leapFebruary() {
        #expect(GridLayoutMath.daysInMonth(month: 2, year: 2028) == 29)
    }

    @Test("allDates(forYear:) produces 365 dates in a non-leap year")
    func allDatesCountsNonLeapYear() {
        #expect(GridLayoutMath.allDates(forYear: 2026).count == 365)
    }

    @Test("allDates(forYear:) produces 366 dates in a leap year")
    func allDatesCountsLeapYear() {
        #expect(GridLayoutMath.allDates(forYear: 2028).count == 366)
    }

    @Test("rect places January 1st at the grid origin")
    func rectPlacesJanuaryFirstAtOrigin() {
        let jan1 = LocalDate(year: 2026, month: 1, day: 1)
        let rect = GridLayoutMath.rect(for: jan1, cellSize: CGSize(width: 10, height: 10), spacing: 2)
        #expect(rect.origin == .zero)
    }

    @Test("rect advances column by day and row by month")
    func rectAdvancesByDayAndMonth() {
        let feb2 = LocalDate(year: 2026, month: 2, day: 2)
        let rect = GridLayoutMath.rect(for: feb2, cellSize: CGSize(width: 10, height: 10), spacing: 2)
        #expect(rect.origin.x == 12) // 1 column * (10 + 2)
        #expect(rect.origin.y == 12) // 1 row * (10 + 2)
    }
}

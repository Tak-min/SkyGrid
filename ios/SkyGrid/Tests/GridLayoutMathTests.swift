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

    @Test("sequential dates start at day 1 regardless of its weekday and pack with no gaps")
    func sequentialDatesPackFromDayOne() {
        // August 2026 starts on Saturday: a weekday-based calendar would leave six
        // leading blanks, but the pixel-art mosaic always opens on day 1.
        let dates = GridLayoutMath.sequentialDates(year: 2026, month: 8)

        #expect(dates.count == 31)
        #expect(dates.first == LocalDate(year: 2026, month: 8, day: 1))
        #expect(dates.last == LocalDate(year: 2026, month: 8, day: 31))
    }

    @Test("sequential dates match the month's actual day count in a leap February")
    func sequentialDatesMatchLeapFebruary() {
        let dates = GridLayoutMath.sequentialDates(year: 2028, month: 2)
        #expect(dates.count == 29)
        #expect(dates.last == LocalDate(year: 2028, month: 2, day: 29))
    }

    @Test("aspectFillRect leaves a square image matching a square bounds untouched")
    func aspectFillRectSquareMatchesSquare() {
        let bounds = CGRect(x: 0, y: 0, width: 60, height: 60)
        let rect = GridLayoutMath.aspectFillRect(imageSize: CGSize(width: 200, height: 200), in: bounds)
        #expect(rect == bounds)
    }

    @Test("aspectFillRect grows a portrait image's height to cover square bounds, centred")
    func aspectFillRectPortraitCoversSquareBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 60, height: 60)
        // 3:4 portrait (narrower than tall): matching the bounds' width is the
        // tighter constraint, so the scaled height overshoots and gets cropped
        // top/bottom instead — matching the bounds' height would leave gaps on
        // the sides, which "cover" must never do.
        let rect = GridLayoutMath.aspectFillRect(imageSize: CGSize(width: 300, height: 400), in: bounds)
        #expect(rect.width == bounds.width)
        #expect(rect.height > bounds.height)
        #expect(rect.midY == bounds.midY)
        #expect(rect.minX == bounds.minX)
    }

    @Test("aspectFillRect grows a landscape image's width to cover square bounds, centred")
    func aspectFillRectLandscapeCoversSquareBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 60, height: 60)
        // Mirror image of the portrait case: matching the bounds' height is the
        // tighter constraint, so the scaled width overshoots and gets cropped
        // left/right.
        let rect = GridLayoutMath.aspectFillRect(imageSize: CGSize(width: 400, height: 300), in: bounds)
        #expect(rect.height == bounds.height)
        #expect(rect.width > bounds.width)
        #expect(rect.midX == bounds.midX)
        #expect(rect.minY == bounds.minY)
    }

    @Test("aspectFillRect falls back to bounds for a degenerate zero-size image")
    func aspectFillRectZeroSizeFallsBackToBounds() {
        let bounds = CGRect(x: 5, y: 5, width: 60, height: 40)
        #expect(GridLayoutMath.aspectFillRect(imageSize: .zero, in: bounds) == bounds)
    }
}

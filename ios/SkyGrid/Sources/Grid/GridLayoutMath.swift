import Foundation
import CoreGraphics

/// Pure geometry for the 365-cell Sky Grid: each horizontal row is a month and each
/// column is a day. The complete year therefore reads in one glance instead of
/// becoming a tall, mostly-empty wall; missing dates (e.g. February 30) are simply
/// not drawn.
enum GridLayoutMath {
    static let columns = 31
    static let rows = 12

    static func daysInMonth(month: Int, year: Int) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: year, month: month))!
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    static func allDates(forYear year: Int) -> [LocalDate] {
        (1...12).flatMap { month in
            (1...daysInMonth(month: month, year: year)).map { day in
                LocalDate(year: year, month: month, day: day)
            }
        }
    }

    static func cellSize(for containerSize: CGSize, spacing: CGFloat) -> CGSize {
        let totalSpacingX = spacing * CGFloat(columns - 1)
        let totalSpacingY = spacing * CGFloat(rows - 1)
        let width = (containerSize.width - totalSpacingX) / CGFloat(columns)
        let height = (containerSize.height - totalSpacingY) / CGFloat(rows)
        return CGSize(width: width, height: height)
    }

    /// `column = day - 1`, `row = month - 1` — top-left origin, matching `Canvas`'s
    /// coordinate space.
    static func rect(for date: LocalDate, cellSize: CGSize, spacing: CGFloat) -> CGRect {
        let column = date.day - 1
        let row = date.month - 1
        let x = CGFloat(column) * (cellSize.width + spacing)
        let y = CGFloat(row) * (cellSize.height + spacing)
        return CGRect(x: x, y: y, width: cellSize.width, height: cellSize.height)
    }
}

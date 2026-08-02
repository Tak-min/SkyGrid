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

    /// Day 1 always sits in the grid's top-left slot, with every following day
    /// packed immediately after it — a dense mosaic block rather than a calendar
    /// (which would offset day 1 by its weekday and leave ragged leading gaps).
    /// The photo archive reads as a pixel-art field, not a datebook.
    static func sequentialDates(year: Int, month: Int) -> [LocalDate] {
        (1...daysInMonth(month: month, year: year)).map { LocalDate(year: year, month: month, day: $0) }
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

    /// The rect to draw an image of `imageSize` into so it covers `bounds` without
    /// distortion, centred — an aspect-fill crop. `GraphicsContext.draw(_:in:)`
    /// stretches an image non-uniformly to exactly fill whatever rect it's given, so
    /// aspect-fill has to be computed here rather than requested from the context.
    static func aspectFillRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

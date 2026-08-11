import Foundation
import CoreGraphics

/// Packing geometry for the share card's captured-sky contact sheet — the block of
/// only-the-days-that-exist that replaced the literal 31×12 calendar as the year
/// card's hero on 2026-08-11.
///
/// Pure and separate from the view for the same reason `GridLayoutMath` is: the
/// numbers change shape with the count, and the counts that matter (1, 20, 365) are
/// months or a year apart in a real user's life. A regression at 365 would otherwise
/// be found by a user before it is found by us.
enum ContactSheetLayout {
    /// A single capture must not become a 420pt tile. Past this the sheet centres
    /// rather than enlarging: the source is a cached thumbnail, and blowing one up to
    /// most of the panel is how a share card starts looking like a mistake.
    static let maximumCellSide: CGFloat = 420

    /// Biases the block toward the panel's landscape aspect. A plain `sqrt(count)`
    /// packs into a square, which leaves two vertical bands of the panel empty.
    private static let aspectBias = 1.3

    struct Layout: Equatable {
        let columns: Int
        let rows: Int
        let cellSide: CGFloat
        let gap: CGFloat
        /// Top-left of the packed block, already centred inside the panel.
        let origin: CGPoint
    }

    /// Tighter as the sheet gets denser: at 365 captures a 10pt gutter would take more
    /// of the panel than the photographs do.
    static func gap(forCount count: Int) -> CGFloat {
        if count > 144 { return 4 }
        if count > 49 { return 6 }
        return 10
    }

    static func columns(forCount count: Int) -> Int {
        guard count > 0 else { return 1 }
        return max(1, Int((Double(count) * aspectBias).squareRoot().rounded()))
    }

    /// `nil` for an empty sheet — the caller draws its own empty state rather than
    /// being handed a degenerate layout to render.
    static func layout(count: Int, in size: CGSize) -> Layout? {
        guard count > 0, size.width > 0, size.height > 0 else { return nil }

        let columns = columns(forCount: count)
        let rows = Int((Double(count) / Double(columns)).rounded(.up))
        let gap = gap(forCount: count)

        let widthCell = (size.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let heightCell = (size.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
        // Floored so every tile lands on a whole point: `ImageRenderer` draws at
        // scale 1, and a fractional side leaves a seam between adjacent skies.
        let cellSide = min(widthCell, heightCell, maximumCellSide).rounded(.down)
        guard cellSide > 0 else { return nil }

        let blockWidth = CGFloat(columns) * cellSide + CGFloat(columns - 1) * gap
        let blockHeight = CGFloat(rows) * cellSide + CGFloat(rows - 1) * gap

        return Layout(
            columns: columns,
            rows: rows,
            cellSide: cellSide,
            gap: gap,
            origin: CGPoint(
                x: (size.width - blockWidth) / 2,
                y: (size.height - blockHeight) / 2
            )
        )
    }

    /// Where the `index`-th capture sits, in reading order.
    static func rect(at index: Int, layout: Layout) -> CGRect {
        CGRect(
            x: layout.origin.x + CGFloat(index % layout.columns) * (layout.cellSide + layout.gap),
            y: layout.origin.y + CGFloat(index / layout.columns) * (layout.cellSide + layout.gap),
            width: layout.cellSide,
            height: layout.cellSide
        )
    }
}

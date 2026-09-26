import SwiftUI
import UIKit

/// The 365-cell photo mosaic is drawn as a single `Canvas`, not 365 separate
/// `View`s. Each loaded cell is the user's actual sky photo; unloaded records stay
/// neutral rather than being represented by an extracted average colour. Since
/// `ImageProcessor` now guarantees every thumbnail is square, `aspectFillRect`
/// below is normally a no-op crop — it stays in place as a safety net for any
/// pre-fix, non-square thumbnail still cached on a device, so a stretched/distorted
/// cell degrades to a correctly-cropped one instead of a warped one.
struct GridCanvas: View {
    let year: Int
    let postedDates: Set<LocalDate>
    let thumbnails: [LocalDate: UIImage]
    /// Days with a photo in the local outbox but no confirmed post yet (see
    /// `PendingCellState`). Deliberately never plumbed into the share-card export
    /// path — `GridArchiveView.shareGrid()` builds `ShareCardRenderer` from
    /// `visiblePosts`/its own photo dict directly, bypassing this view entirely, so
    /// an unconfirmed day can never appear in a shared artifact.
    var pendingStates: [LocalDate: PendingCellState] = [:]
    var spacing: CGFloat = 1.5

    /// Injectable so the share-card export can render the same mosaic on its dark
    /// ground. `SGT.ghost`/`SGT.fill` are tuned for the warm in-app background and
    /// turn to mud on `SGExport.ground`.
    var emptyFill: Color = SGT.ghost
    var postedNoThumbFill: Color = SGT.fill

    /// Alternating per-month wash behind the cells. Without it a year of mostly
    /// empty days is one undifferentiated grey block: there is no way to tell which
    /// row is which month, and the days that don't exist (Feb 30, Apr 31) read as
    /// white rectangular glitches at the ragged right edge rather than as the end of
    /// a month. Banding draws only across the days a month actually has, so that
    /// edge becomes legible calendar shape.
    var monthBanding: Bool = false
    var bandFill: Color = SGT.ghostFaint

    var body: some View {
        Canvas { context, size in
            let cellSize = GridLayoutMath.cellSize(for: size, spacing: spacing)
            // Symbol scale is a fraction of the cell, not a fixed point size: at
            // the year view's ~29pt cells the glyph needs to stay legible without
            // overrunning the (typically single) pending cell's bounds.
            let symbolInset = min(cellSize.width, cellSize.height) * 0.26

            if monthBanding {
                for month in 1...GridLayoutMath.rows where month.isMultiple(of: 2) {
                    let days = GridLayoutMath.daysInMonth(month: month, year: year)
                    let first = GridLayoutMath.rect(
                        for: LocalDate(year: year, month: month, day: 1),
                        cellSize: cellSize,
                        spacing: spacing
                    )
                    let last = GridLayoutMath.rect(
                        for: LocalDate(year: year, month: month, day: days),
                        cellSize: cellSize,
                        spacing: spacing
                    )
                    let band = CGRect(
                        x: first.minX,
                        y: first.minY,
                        width: last.maxX - first.minX,
                        height: first.height
                    )
                    context.fill(Path(band), with: .color(bandFill))
                }
            }

            for date in GridLayoutMath.allDates(forYear: year) {
                let rect = GridLayoutMath.rect(for: date, cellSize: cellSize, spacing: spacing)
                let cornerRadius = spacing == 0 ? 0 : min(2, cellSize.width * 0.15)
                let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
                if let thumbnail = thumbnails[date] {
                    var clippedContext = context
                    clippedContext.clip(to: path)
                    let imageRect = GridLayoutMath.aspectFillRect(imageSize: thumbnail.size, in: rect)
                    clippedContext.draw(clippedContext.resolve(Image(uiImage: thumbnail)), in: imageRect)
                } else if postedDates.contains(date) {
                    context.fill(path, with: .color(postedNoThumbFill))
                } else if let pendingState = pendingStates[date] {
                    context.fill(path, with: .color(postedNoThumbFill))
                    if let symbol = context.resolveSymbol(id: pendingState) {
                        context.draw(symbol, in: rect.insetBy(dx: symbolInset, dy: symbolInset))
                    }
                } else {
                    let isBandedMonth = monthBanding && date.month.isMultiple(of: 2)
                    context.fill(path, with: .color(isBandedMonth ? bandFill : emptyFill))
                }
            }
        } symbols: {
            ForEach(PendingCellState.allCases, id: \.self) { state in
                Image(systemName: state.symbolName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SGT.ink2)
                    .tag(state)
            }
        }
    }
}

import SwiftUI

/// The 365-cell mosaic drawn as a single `Canvas`, not 365 separate `View`s. This
/// keeps its one-glance annual view efficient both on screen and in share exports.
struct GridCanvas: View {
    let year: Int
    let colors: [LocalDate: SkyColor]
    var spacing: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            let cellSize = GridLayoutMath.cellSize(for: size, spacing: spacing)
            for date in GridLayoutMath.allDates(forYear: year) {
                let rect = GridLayoutMath.rect(for: date, cellSize: cellSize, spacing: spacing)
                let path = Path(roundedRect: rect, cornerRadius: min(2, cellSize.width * 0.15))
                if let sky = colors[date] {
                    context.fill(path, with: .color(sky.color))
                } else {
                    context.fill(path, with: .color(SGT.ghost))
                }
            }
        }
    }
}

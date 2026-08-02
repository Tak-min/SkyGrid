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
    var spacing: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            let cellSize = GridLayoutMath.cellSize(for: size, spacing: spacing)
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
                    context.fill(path, with: .color(SGT.fill))
                } else {
                    context.fill(path, with: .color(SGT.ghost))
                }
            }
        }
    }
}

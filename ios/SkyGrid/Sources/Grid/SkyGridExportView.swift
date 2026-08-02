import SwiftUI
import UIKit

/// A separate, fixed 9:16 layout for share-card export — NOT the on-screen
/// `SkyGridView` (which scrolls and adapts to the device). `ShareCardRenderer`
/// snapshots this view specifically. Draws the same `GridCanvas` the on-screen year
/// mosaic uses, so the exported card shows the user's real photos rather than the
/// average-colour record it used to render — the share card and the in-app archive
/// were a deliberately different pair before this change (see dev-notes); real
/// photos everywhere is the point of this change.
struct SkyGridExportView: View {
    let year: Int
    let postedDates: Set<LocalDate>
    let photos: [LocalDate: UIImage]

    /// Integer cell size avoids subpixel seams between adjacent tiles in a
    /// "pixel art" export. 31 columns × 30pt = 930pt, 12 rows × 30pt = 360pt.
    private static let cellSize: CGFloat = 30
    private static let canvasWidth = cellSize * CGFloat(GridLayoutMath.columns)
    private static let canvasHeight = cellSize * CGFloat(GridLayoutMath.rows)

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 8) {
                Text("SKY GRID")
                    .font(SGFont.caption(16))
                    .tracking(3)
                    .foregroundStyle(SGT.ink3)
                Text(String(year))
                    .font(SGFont.serifTitle(64))
                    .foregroundStyle(SGT.ink)
                Text("\(postedDates.count) mornings")
                    .font(SGFont.numeric(22))
                    .foregroundStyle(SGT.ink2)
            }
            .padding(.horizontal, 76)
            GridCanvas(year: year, postedDates: postedDates, thumbnails: photos, spacing: 0)
                .frame(width: Self.canvasWidth, height: Self.canvasHeight)
                .padding(.horizontal, (1080 - Self.canvasWidth) / 2)
            Text("one sky, every morning")
                .font(SGFont.caption(18))
                .foregroundStyle(SGT.ink3)
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer(minLength: 0)
        }
        .frame(width: 1080, height: 1920)
        .background(SGT.background)
    }
}

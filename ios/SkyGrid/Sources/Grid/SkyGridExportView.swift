import SwiftUI
import UIKit

/// A separate, fixed 9:16 layout for share-card export — NOT the on-screen
/// `SkyGridView` (which scrolls and adapts to the device). `ShareCardRenderer`
/// snapshots this view specifically. Draws the same `GridCanvas` the on-screen year
/// mosaic uses, so the exported card shows the user's real photos rather than the
/// average-colour record it used to render.
///
/// **Designed for a feed, not for the app.** The previous version rendered on the
/// warm `SGT.background` with grey labels and a 64pt serif year: in an Instagram or
/// TikTok Story it was a pale cream rectangle, and at the ~120px width of a story
/// tray its largest text was about 7px tall — unreadable, so it stopped no one.
/// Three things changed:
///
/// 1. A fixed dark ground (`SGExport.ground`) so the user's own skies are the only
///    chroma on the card. This is both maximum contrast and the most on-concept
///    choice available, since the sky colour *is* this product's accent.
/// 2. The hero is a number at 300pt `.black`, which survives thumbnail scale.
/// 3. The ground is non-adaptive. `SGT.background` is a trait-adaptive colour, and
///    `ImageRenderer` resolves those against an unpinned trait environment — so the
///    exported card's background silently depended on the exporting device's
///    appearance instead of being a fixed artifact.
struct SkyGridExportView: View {
    let year: Int
    let postedDates: Set<LocalDate>
    let photos: [LocalDate: UIImage]
    /// The person's handle, for attribution. `nil` renders the app's mark instead —
    /// a handle is never synthesised.
    var handle: Handle?

    /// Integer cell size avoids subpixel seams between adjacent tiles. Spacing of 2
    /// (was 0) so individual days are countable instead of smeared into a block:
    /// 31 × 30 + 30 × 2 = 990 wide, 12 × 30 + 11 × 2 = 382 tall.
    private static let cellSize: CGFloat = 30
    private static let cellSpacing: CGFloat = 2
    private static let canvasWidth = cellSize * CGFloat(GridLayoutMath.columns)
        + cellSpacing * CGFloat(GridLayoutMath.columns - 1)
    private static let canvasHeight = cellSize * CGFloat(GridLayoutMath.rows)
        + cellSpacing * CGFloat(GridLayoutMath.rows - 1)

    private static let margin: CGFloat = 88

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text("SKY GRID")
                .font(SGFont.fixedCaption(26))
                .tracking(8)
                .foregroundStyle(SGExport.ink2)
                .padding(.bottom, 28)

            // The count of mornings is the brag, and it is a fact about this
            // specific grid — unlike a current streak, which would be meaningless
            // on a card exported for a past year.
            HStack(alignment: .lastTextBaseline, spacing: 18) {
                Text("\(postedDates.count)")
                    .font(SGFont.fixedDisplay(300, weight: .black))
                    .tracking(-8)
                    .foregroundStyle(SGExport.ink)
                Text(postedDates.count == 1 ? "morning" : "mornings")
                    .font(SGFont.fixedCaption(38))
                    .foregroundStyle(SGExport.ink2)
                    .padding(.bottom, 44)
            }
            .padding(.bottom, 12)

            Text("in \(String(year))")
                .font(SGFont.fixedNumeric(34))
                .foregroundStyle(SGExport.ink3)
                .padding(.bottom, 56)

            GridCanvas(
                year: year,
                postedDates: postedDates,
                thumbnails: photos,
                spacing: Self.cellSpacing,
                emptyFill: SGExport.cellEmpty,
                postedNoThumbFill: SGExport.cellPostedNoThumb,
                monthBanding: true,
                bandFill: Color.white.opacity(0.03)
            )
            .frame(width: Self.canvasWidth, height: Self.canvasHeight)

            Spacer(minLength: 0)
            downloadFooter
        }
        .padding(.horizontal, Self.margin)
        .padding(.vertical, 96)
        .frame(width: 1080, height: 1920)
        .background(SGExport.ground)
        // Belt-and-braces against trait-adaptive resolution inside ImageRenderer:
        // every token above is already fixed, and this pins anything nested.
        .environment(\.colorScheme, .dark)
    }

    private var downloadFooter: some View {
        HStack(spacing: 20) {
            // A fixed white quiet zone keeps the code scannable regardless of the
            // surrounding theme's background colour.
            if let qrImage = QRCodeGenerator.image(for: SGExport.downloadURLString) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 8) {
                if let handle {
                    Text("@\(handle.value)")
                        .font(SGFont.fixedNumeric(34, weight: .semibold))
                        .foregroundStyle(SGExport.ink)
                }
                Text("Sky Grid — one sky, every morning")
                    .font(SGFont.fixedCaption(24))
                    .foregroundStyle(SGExport.ink2)
            }
            Spacer(minLength: 0)
        }
    }
}

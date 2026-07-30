import SwiftUI

/// A separate, fixed 9:16 layout for share-card export — NOT the on-screen
/// `SkyGridView` (which scrolls and adapts to the device). `ShareCardRenderer`
/// snapshots this view specifically.
struct SkyGridExportView: View {
    let year: Int
    let colors: [LocalDate: SkyColor]

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
                Text("\(colors.count) mornings")
                    .font(SGFont.numeric(22))
                    .foregroundStyle(SGT.ink2)
            }
            .padding(.horizontal, 76)
            GridCanvas(year: year, colors: colors)
                .aspectRatio(CGFloat(GridLayoutMath.columns) / CGFloat(GridLayoutMath.rows), contentMode: .fit)
                .padding(.horizontal, 76)
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

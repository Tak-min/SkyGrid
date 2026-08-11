import SwiftUI
import UIKit

/// A separate, fixed 9:16 layout for share-card export — NOT the on-screen
/// `SkyGridView` (which scrolls and adapts to the device). `ShareCardRenderer`
/// snapshots this view specifically.
///
/// **Designed for a feed, not for the app.** Two rounds of that:
///
/// The first (2026-08) moved off the warm in-app ground onto a fixed dark one, so the
/// user's own skies are the only chroma and the card survives being rendered ~120px
/// wide in a story tray.
///
/// The second (2026-08-11) fixed what that version still got wrong: **it gave absence
/// more area than evidence.** The card drew the literal 31×12 calendar, so a real user
/// with 20 captured mornings spent ~94% of the hero on empty cells. Each photo was one
/// 30pt tile — about 3px once the card is a story-tray thumbnail — so the mosaic that
/// is supposed to be the product read as a grey rectangle with a coloured stripe in it.
///
/// The fix splits the one grid into two things that were being asked of it at once:
///
/// - `CapturedSkyMosaicExportView` — the hero. Only days that were actually captured,
///   packed chronologically, so 20 mornings are ~146pt tiles instead of ~30pt ones.
///   Photographs, not the absence of them, get the area.
/// - `YearMapExportView` — the truth-keeper. The exact 31×12 calendar, kept so the
///   card cannot be read as claiming the packed sheet *is* the shape of the year.
///   Un-captured days are 4pt guide dots rather than filled tiles.
///
/// Every colour is non-adaptive. `SGT`'s tokens resolve through `Color(UIColor { … })`,
/// and `ImageRenderer` resolves those against an unpinned trait environment — which
/// once made the exported card's ground depend on the exporting device's appearance.
struct SkyGridExportView: View {
    let year: Int
    let postedDates: Set<LocalDate>
    let photos: [LocalDate: UIImage]
    /// The person's handle, for attribution. `nil` renders the app's mark alone —
    /// a handle is never synthesised.
    var handle: Handle?

    private static let margin: CGFloat = 80
    private static let contentWidth: CGFloat = 1080 - margin * 2

    /// Only days belonging to the rendered year count, and only they are drawn. A
    /// caller passing a neighbouring year's date cannot make the headline number
    /// disagree with the year printed beside it.
    private var capturedDates: [LocalDate] {
        postedDates.filter { $0.year == year }.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 48)

            statement
                .padding(.bottom, 44)

            CapturedSkyMosaicExportView(dates: capturedDates, photos: photos)
                .frame(width: Self.contentWidth, height: 680)
                .padding(.bottom, 40)

            yearMap

            Spacer(minLength: 36)

            AppStoreIdentity(handle: handle)
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, 104)
        // Story UI (the reply bar, the "send to" row) crowds the bottom of a 9:16
        // frame. Nothing the card needs read sits in the last 176pt.
        .padding(.bottom, 176)
        .frame(width: 1080, height: 1920)
        .background(SGExport.groundGradient)
        // Belt-and-braces against trait-adaptive resolution inside ImageRenderer:
        // every token above is already fixed, and this pins anything nested.
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("SKY GRID")
                .font(SGFont.fixedCaption(28))
                .tracking(8)
                .foregroundStyle(SGExport.inkMuted)

            Spacer(minLength: 24)

            Text(String(year))
                .font(SGFont.fixedNumeric(30, weight: .semibold))
                .foregroundStyle(SGExport.inkMuted)
        }
    }

    /// The count and what the count *is*, as one lockup rather than a numeral with a
    /// word trailing off its baseline. "mornings" alone could be a habit tracker or an
    /// alarm log; "morning skies photographed" is the whole product in three words,
    /// which is all a stranger scrolling a story gets.
    private var statement: some View {
        let count = capturedDates.count
        return HStack(alignment: .center, spacing: 28) {
            Text("\(count)")
                .font(SGFont.fixedDisplay(232, weight: .black))
                .tracking(-6)
                .foregroundStyle(SGExport.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 420, alignment: .trailing)

            VStack(alignment: .leading, spacing: 12) {
                Text(count == 1 ? "morning\nsky" : "morning\nskies")
                    .font(SGFont.fixedSerifTitle(62))
                    .foregroundStyle(SGExport.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("PHOTOGRAPHED THIS YEAR")
                    .font(SGFont.fixedCaption(23))
                    .tracking(2.2)
                    .foregroundStyle(SGExport.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var yearMap: some View {
        VStack(spacing: 16) {
            HStack {
                Text("THE YEAR")
                    .font(SGFont.fixedCaption(22))
                    .tracking(3)
                    .foregroundStyle(SGExport.inkMuted)

                Spacer(minLength: 24)

                Text("JAN → DEC")
                    .font(SGFont.fixedCaption(22))
                    .tracking(3)
                    .foregroundStyle(SGExport.inkMuted)
            }

            YearMapExportView(year: year, postedDates: Set(capturedDates))
                .frame(width: Self.contentWidth, height: 182)
        }
    }
}

/// A chronological contact sheet of the mornings that exist. Unlike the calendar map
/// below it, it spends no area on days that hold no photograph — which is the entire
/// reason it exists.
///
/// The filename rule: this lives in a `*ExportView.swift` file, which is what keeps it
/// inside the `SGExport` boundary allowlist documented in `DesignSystem/ExportTheme.swift`.
private struct CapturedSkyMosaicExportView: View {
    let dates: [LocalDate]
    let photos: [LocalDate: UIImage]

    private static let inset: CGFloat = 34
    private static let cornerRadius: CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .fill(SGExport.surface)

            if dates.isEmpty {
                emptyState
            } else {
                sheet.padding(Self.inset)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(SGExport.hairline, lineWidth: 2)
        }
    }

    /// Reachable only for a year with no captures at all. It says so rather than
    /// rendering an empty panel that looks like a failed image load.
    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "sun.horizon")
                .font(.system(size: 52, weight: .regular))
            Text("NO SKIES YET")
                .font(SGFont.fixedCaption(26))
                .tracking(3)
        }
        .foregroundStyle(SGExport.inkMuted)
    }

    private var sheet: some View {
        Canvas { context, size in
            guard let layout = ContactSheetLayout.layout(count: dates.count, in: size) else { return }
            let cell = layout.cellSide

            for (index, date) in dates.enumerated() {
                let rect = ContactSheetLayout.rect(at: index, layout: layout)
                let path = Path(roundedRect: rect, cornerRadius: min(18, cell * 0.12))

                if let photo = photos[date] {
                    var clipped = context
                    clipped.clip(to: path)
                    clipped.draw(
                        clipped.resolve(Image(uiImage: photo)),
                        in: GridLayoutMath.aspectFillRect(imageSize: photo.size, in: rect)
                    )
                } else {
                    // The morning happened; its image just isn't loaded. A marked
                    // neutral tile reports that without inventing a sky colour, and
                    // without changing the count the headline already stated.
                    context.fill(path, with: .color(SGExport.surfaceRaised))
                    let dot = max(6, cell * 0.075)
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: rect.midX - dot / 2,
                            y: rect.midY - dot / 2,
                            width: dot,
                            height: dot
                        )),
                        with: .color(SGExport.inkMuted)
                    )
                }

                context.stroke(path, with: .color(SGExport.hairline), lineWidth: max(1, cell * 0.012))
            }
        }
    }
}

/// The canonical 31 columns × 12 rows, kept so the packed contact sheet above can
/// never be mistaken for a claim about *when* in the year those mornings happened.
/// Captured days are filled dots; the rest are small guides. Geometry comes from
/// `GridLayoutMath` rather than being re-derived here, so there is one definition of
/// where a date sits in this app.
private struct YearMapExportView: View {
    let year: Int
    let postedDates: Set<LocalDate>

    private static let spacing: CGFloat = 2
    private static let guideSide: CGFloat = 4

    var body: some View {
        Canvas { context, size in
            let cellSize = GridLayoutMath.cellSize(for: size, spacing: Self.spacing)
            for date in GridLayoutMath.allDates(forYear: year) {
                let cell = GridLayoutMath.rect(for: date, cellSize: cellSize, spacing: Self.spacing)
                let isPosted = postedDates.contains(date)
                let side = isPosted ? min(cellSize.width, cellSize.height) * 0.86 : Self.guideSide
                let dot = CGRect(
                    x: cell.midX - side / 2,
                    y: cell.midY - side / 2,
                    width: side,
                    height: side
                )
                context.fill(
                    Path(ellipseIn: dot),
                    with: .color(isPosted ? SGExport.ink2 : SGExport.guide)
                )
            }
        }
    }
}

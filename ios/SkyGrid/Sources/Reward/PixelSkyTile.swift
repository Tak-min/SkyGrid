import SwiftUI
import UIKit

/// The reward's disposable, derived representation of a captured sky. It always
/// samples a real square thumbnail at the single 24×24 logical resolution fixed by
/// DESIGN.md, then SwiftUI scales those samples with nearest-neighbour filtering.
/// It never writes, uploads, or replaces the original photo.
enum PixelSkyTileRenderer {
    static let logicalEdge: CGFloat = 24

    static func makeTile(from thumbnailData: Data?) -> UIImage? {
        guard let thumbnailData, let source = UIImage(data: thumbnailData) else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: logicalEdge, height: logicalEdge),
            format: format
        )
        return renderer.image { _ in
            let scale = max(logicalEdge / source.size.width, logicalEdge / source.size.height)
            let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            source.draw(in: CGRect(
                x: (logicalEdge - size.width) / 2,
                y: (logicalEdge - size.height) / 2,
                width: size.width,
                height: size.height
            ))
        }
    }
}

/// A small, self-contained preview of the actual current-day slot. Other cells are
/// intentionally neutral: the reward has no archive observation of its own, and it
/// must not invent previously captured photos just to make the mosaic look full.
struct RewardMosaicLandingView: View {
    let sourceThumbnail: UIImage?
    let tile: UIImage?
    let fallbackColor: Color
    let localDate: LocalDate
    let beat: RewardBeat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = 7
    private let rows = 5

    var body: some View {
        GeometryReader { proxy in
            let cell = (proxy.size.width - CGFloat(columns - 1) * 3) / CGFloat(columns)
            let target = targetCenter(cell: cell)
            let isLanded = beat == .mosaicLanding || beat == .rewardPeak || beat == .settle
            let isDerived = beat != .captureConfirmation

            ZStack(alignment: .topLeading) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 3), count: columns), spacing: 3) {
                    ForEach(0..<(columns * rows), id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(index == targetIndex && isLanded ? fallbackColor.opacity(0.25) : SGT.ghost)
                            .frame(width: cell, height: cell)
                    }
                }

                tileView(isDerived: isDerived)
                    .frame(width: isDerived ? cell : 132, height: isDerived ? cell : 132)
                    .position(
                        x: isLanded || reduceMotion ? target.x : proxy.size.width / 2,
                        y: isLanded || reduceMotion ? target.y : proxy.size.height + 74
                    )
                    .opacity(beat == .captureConfirmation || isDerived ? 1 : 0)
                    .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.34, dampingFraction: 0.78), value: beat)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func tileView(isDerived: Bool) -> some View {
        if !isDerived, let sourceThumbnail {
            Image(uiImage: sourceThumbnail)
                .resizable()
                .scaledToFill()
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if let tile {
            Image(uiImage: tile)
                .resizable()
                .interpolation(.none)
                .scaledToFill()
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(fallbackColor)
        }
    }

    private var targetIndex: Int {
        // A stable, date-derived slot makes the landing mean "today joins this
        // calendar" without pretending this overlay has loaded the full archive.
        ((localDate.month - 1) * 3 + (localDate.day - 1)) % (columns * rows)
    }

    private func targetCenter(cell: CGFloat) -> CGPoint {
        let column = targetIndex % columns
        let row = targetIndex / columns
        return CGPoint(
            x: CGFloat(column) * (cell + 3) + cell / 2,
            y: CGFloat(row) * (cell + 3) + cell / 2
        )
    }
}

import SwiftUI

/// An illustrative mosaic, never a user's saved grid. It stays still while Moku
/// moves independently above it; ordinary screens never animate the entire grid.
struct RitualGridMark: View {
    let side: CGFloat

    init(side: CGFloat = 172) {
        self.side = side
    }

    private let colors: [Color] = [
        Color(red: 0.78, green: 0.86, blue: 0.89),
        Color(red: 0.92, green: 0.76, blue: 0.61),
        Color(red: 0.64, green: 0.75, blue: 0.78),
        Color(red: 0.82, green: 0.79, blue: 0.68),
        Color(red: 0.49, green: 0.61, blue: 0.70),
        Color(red: 0.89, green: 0.67, blue: 0.58),
    ]

    var body: some View {
        Canvas { context, size in
            let columns = 7
            let rows = 7
            let gap: CGFloat = 4
            let side = min(
                (size.width - CGFloat(columns - 1) * gap) / CGFloat(columns),
                (size.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
            )
            let totalWidth = side * CGFloat(columns) + gap * CGFloat(columns - 1)
            let totalHeight = side * CGFloat(rows) + gap * CGFloat(rows - 1)
            let origin = CGPoint(x: (size.width - totalWidth) / 2, y: (size.height - totalHeight) / 2)

            for row in 0..<rows {
                for column in 0..<columns {
                    let index = row * columns + column
                    let rect = CGRect(
                        x: origin.x + CGFloat(column) * (side + gap),
                        y: origin.y + CGFloat(row) * (side + gap),
                        width: side,
                        height: side
                    )
                    let path = Path(roundedRect: rect, cornerRadius: side * 0.22)
                    let fill = index < 24 ? colors[index % colors.count] : SGT.ghost
                    context.fill(path, with: .color(fill))
                }
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

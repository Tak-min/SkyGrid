import SwiftUI

/// The year is a physical-looking field of days, not a progress chart. Every empty
/// cell stays visible so the color record can be read alongside the ordinary gaps.
struct SkyGridView: View {
    let year: Int
    let colors: [LocalDate: SkyColor]
    var canShare = false
    var onShare: (() -> Void)?
    var archiveNotice: String?
    var onUpgrade: (() -> Void)?

    private var postedCount: Int { colors.count }
    private var totalDays: Int { GridLayoutMath.allDates(forYear: year).count }
    private var ambientColor: Color { colors.values.first?.color ?? SGT.background }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ambientColor.opacity(0.13), SGT.background, SGT.background],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SGSpacing.xl) {
                    header
                    gridField
                    Text("January through December, one day at a time.")
                        .font(SGFont.caption(12))
                        .foregroundStyle(SGT.ink3)
                        .frame(maxWidth: .infinity, alignment: .center)
                    if let archiveNotice, let onUpgrade {
                        VStack(spacing: SGSpacing.sm) {
                            Text(archiveNotice)
                                .font(SGFont.caption(12))
                                .foregroundStyle(SGT.ink3)
                            Button("Unlock the full archive", action: onUpgrade)
                                .font(SGFont.body(15))
                                .foregroundStyle(SGT.ink2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, SGSpacing.xl)
                .padding(.top, SGSpacing.lg)
                .padding(.bottom, 42)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: SGSpacing.xs) {
                Text("SKY GRID")
                    .font(SGFont.caption(11))
                    .tracking(1.5)
                    .foregroundStyle(SGT.ink3)
                Text(String(year))
                    .font(SGFont.serifTitle(52))
                    .foregroundStyle(SGT.ink)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: SGSpacing.md) {
                Text("\(postedCount) / \(totalDays)")
                    .font(SGFont.numeric(16, weight: .medium))
                    .foregroundStyle(SGT.ink2)
                if let onShare {
                    Button(action: onShare) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(SGFont.caption(13))
                    }
                    .foregroundStyle(SGT.ink2)
                    .disabled(!canShare)
                    .accessibilityLabel("Share Sky Grid")
                }
            }
            .padding(.bottom, SGSpacing.sm)
        }
    }

    private var gridField: some View {
        VStack(spacing: SGSpacing.md) {
            dayLabels
            HStack(alignment: .center, spacing: SGSpacing.sm) {
                monthLabels
                GridCanvas(year: year, colors: colors, spacing: 2)
                    .aspectRatio(CGFloat(GridLayoutMath.columns) / CGFloat(GridLayoutMath.rows), contentMode: .fit)
            }
        }
        .padding(SGSpacing.md)
        .background(SGT.fill.opacity(0.74), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(SGT.rule, lineWidth: 1)
        }
    }

    private var monthLabels: some View {
        VStack(spacing: 0) {
            ForEach(1...12, id: \.self) { month in
                Text("\(month)")
                    .font(SGFont.caption(9))
                    .foregroundStyle(SGT.ink3)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 14)
    }

    private var dayLabels: some View {
        HStack {
            Text("DAY")
                .font(SGFont.caption(9))
                .foregroundStyle(SGT.ink3)
        .frame(width: 22, alignment: .leading)
            HStack {
                Text("1")
                Spacer()
                Text("10")
                Spacer()
                Text("20")
                Spacer()
                Text("31")
            }
            .font(SGFont.caption(9))
            .foregroundStyle(SGT.ink3)
        }
    }
}

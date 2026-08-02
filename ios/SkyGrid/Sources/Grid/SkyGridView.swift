import SwiftUI

/// The year is a physical-looking field of days, not a progress chart. Every empty
/// cell stays visible so the color record can be read alongside the ordinary gaps.
struct SkyGridView: View {
    let year: Int
    let posts: [LocalDate: SkyPost]
    let thumbnails: [LocalDate: UIImage]
    let selectedMonth: Int
    let onSelectMonth: (Int) -> Void
    let onSelectPost: (SkyPost) -> Void
    let lockedPhotoCount: Int
    var canShare = false
    var onShare: (() -> Void)?
    var isPreparingShare = false
    var archiveNotice: String?
    var onUpgrade: (() -> Void)?
    var onSelectPreviousYear: (() -> Void)?
    var onSelectNextYear: (() -> Void)?

    private static let topAnchorID = "sky-grid-header"

    private var postedCount: Int { posts.count }
    private var totalDays: Int { GridLayoutMath.allDates(forYear: year).count }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SGT.fill.opacity(0.56), SGT.background, SGT.background],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            ScrollViewReader { topProxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SGSpacing.xl) {
                        header
                            .id(Self.topAnchorID)
                        gridField
                        monthlyArchive
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
                    // The system's floating tab bar can cover the final calendar week
                    // while scrolling. Keep the archive's last row and upgrade notice
                    // comfortably above it.
                    .padding(.bottom, 128)
                }
                // The TabView keeps this screen alive when a sibling NavigationLink
                // (e.g. Buddies) covers it, so a scroll position from an earlier visit
                // otherwise survives and reappears already scrolled — leaving "SKY
                // GRID" clipped under the status bar instead of at rest. Force back to
                // the top on every appearance so the header is always fully visible.
                .onAppear { topProxy.scrollTo(Self.topAnchorID, anchor: .top) }
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
                HStack(spacing: SGSpacing.md) {
                    if let onSelectPreviousYear {
                        Button(action: onSelectPreviousYear) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(SGT.fill, in: Circle())
                        }
                        .foregroundStyle(SGT.ink2)
                        .accessibilityLabel("Show previous year")
                    }
                    Text(String(year))
                        .font(SGFont.serifTitle(52))
                        .foregroundStyle(SGT.ink)
                    if let onSelectNextYear {
                        Button(action: onSelectNextYear) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(SGT.fill, in: Circle())
                        }
                        .foregroundStyle(SGT.ink2)
                        .accessibilityLabel("Show next year")
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: SGSpacing.md) {
                Text("\(postedCount) / \(totalDays)")
                    .font(SGFont.numeric(16, weight: .medium))
                    .foregroundStyle(SGT.ink2)
                    .contentTransition(.numericText())
                    .skyAnimation(SGMotion.exchange, value: postedCount)
                if canShare, let onShare {
                    Button(action: onShare) {
                        if isPreparingShare {
                            HStack(spacing: SGSpacing.xs) {
                                ProgressView().controlSize(.mini)
                                Text("Preparing…")
                            }
                            .font(SGFont.caption(13))
                        } else {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(SGFont.caption(13))
                        }
                    }
                    .foregroundStyle(SGT.ink2)
                    .disabled(isPreparingShare)
                    .accessibilityLabel(isPreparingShare ? "Preparing Sky Grid to share" : "Share Sky Grid")
                }
            }
            .padding(.bottom, SGSpacing.sm)
        }
    }

    private var gridField: some View {
        VStack(spacing: SGSpacing.md) {
            dayLabels
            HStack(alignment: .center, spacing: 4) {
                monthLabels
                GridCanvas(year: year, postedDates: Set(posts.keys), thumbnails: thumbnails, spacing: 0)
                    .aspectRatio(CGFloat(GridLayoutMath.columns) / CGFloat(GridLayoutMath.rows), contentMode: .fit)
            }
        }
        .accessibilityLabel("A calendar grid of your sky photos")
    }

    private var monthlyArchive: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    Text("PHOTO ARCHIVE")
                        .font(SGFont.caption(11))
                        .tracking(1.2)
                        .foregroundStyle(SGT.ink3)
                    Text("\(monthName(for: selectedMonth)) skies")
                        .font(SGFont.serifTitle(27))
                        .foregroundStyle(SGT.ink)
                }
                Spacer()
                Text("\(monthlyPosts.count) photos")
                    .font(SGFont.caption(12))
                    .foregroundStyle(SGT.ink3)
            }

            monthPicker

            if monthlyPosts.isEmpty, lockedPhotoCount > 0 {
                ContentUnavailableView(
                    "This month is in your full archive",
                    systemImage: "lock",
                    description: Text("Unlock Pro to open its \(lockedPhotoCount) saved photo\(lockedPhotoCount == 1 ? "" : "s").")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, SGSpacing.xl)
                .background(SGT.fill.opacity(0.5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                MonthlyPhotoGrid(
                    year: year,
                    month: selectedMonth,
                    posts: posts,
                    thumbnails: thumbnails,
                    onSelectPost: onSelectPost
                )
                .id(selectedMonth)
                .transition(.opacity)
                if monthlyPosts.isEmpty {
                    Text("No captures in \(monthName(for: selectedMonth)) yet.")
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink3)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .skyAnimation(.easeOut(duration: 0.2), value: selectedMonth)
    }

    private var monthPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SGSpacing.sm) {
                    ForEach(1...12, id: \.self) { month in
                        Button(shortMonthName(for: month)) { onSelectMonth(month) }
                            .font(SGFont.caption(13))
                            .foregroundStyle(month == selectedMonth ? SGT.background : SGT.ink2)
                            .padding(.horizontal, SGSpacing.md)
                            .padding(.vertical, SGSpacing.sm)
                            .background(
                                month == selectedMonth ? SGT.ink : SGT.fill,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule().strokeBorder(SGT.rule, lineWidth: month == selectedMonth ? 0 : 1)
                            }
                            .id(month)
                        }
                    }
                    .skyAnimation(.easeOut(duration: 0.2), value: selectedMonth)
            }
            .onAppear { proxy.scrollTo(selectedMonth, anchor: .center) }
            .onChange(of: selectedMonth) { _, month in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(month, anchor: .center)
                }
            }
        }
    }

    private var monthlyPosts: [SkyPost] {
        posts.values
            .filter { $0.localDate.month == selectedMonth }
            .sorted { $0.localDate < $1.localDate }
    }

    private func monthName(for month: Int) -> String {
        monthFormatter(format: "MMMM", month: month)
    }

    private func shortMonthName(for month: Int) -> String {
        monthFormatter(format: "MMM", month: month).uppercased()
    }

    private func monthFormatter(format: String, month: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return String(month) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.dateFormat = format
        return formatter.string(from: date)
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

private struct MonthlyPhotoGrid: View {
    let year: Int
    let month: Int
    let posts: [LocalDate: SkyPost]
    let thumbnails: [LocalDate: UIImage]
    let onSelectPost: (SkyPost) -> Void

    // Zero spacing on both axes: adjacent tiles abut with no gap, so the block
    // reads as one continuous pixel-art mosaic instead of a spaced-out calendar.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(GridLayoutMath.sequentialDates(year: year, month: month), id: \.self) { date in
                if let post = posts[date] {
                    Button { onSelectPost(post) } label: {
                        ArchivePhotoTile(day: date.day, thumbnail: thumbnails[date], hasPhoto: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open photo from \(date.docID)")
                } else {
                    ArchivePhotoTile(day: date.day, thumbnail: nil, hasPhoto: false)
                }
            }
        }
    }
}

/// `.aspectRatio(1, contentMode: .fit)` reports its *child's* size once that child
/// has been proposed the fitted square — a `Rectangle` (a `Shape`) always accepts
/// exactly the size it's proposed, so anchoring the aspect ratio to the `Rectangle`
/// makes the square real. The photo lives in `.overlay`, which paints without ever
/// feeding back into the parent's reported size, so a non-square or landscape
/// thumbnail can no longer grow the tile past its square slot (verified: putting the
/// `Image` directly in the layout instead — as this view previously did — let a 4:3
/// thumbnail's `scaledToFill` overflow propagate through `.frame(maxWidth: .infinity)`
/// and grow the whole tile 33% past its square bounds; `.clipShape` alone doesn't
/// catch this because it clips to the already-grown rect, not the intended one).
///
/// Square corners and no per-tile border, deliberately: with zero spacing between
/// tiles (`MonthlyPhotoGrid`), a rounded corner or a stroke would leave a visible
/// sliver of background at every seam instead of one continuous mosaic.
private struct ArchivePhotoTile: View {
    let day: Int
    let thumbnail: UIImage?
    let hasPhoto: Bool

    var body: some View {
        Rectangle()
            .fill(hasPhoto ? SGT.fill : SGT.ghost)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else if hasPhoto {
                    ProgressView().controlSize(.mini)
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                Text(String(day))
                    .font(SGFont.numeric(10, weight: .semibold))
                    .foregroundStyle(hasPhoto ? .white : SGT.ink3)
                    .shadow(radius: hasPhoto ? 2 : 0)
                    .padding(4)
            }
    }
}

import SwiftUI

/// The year is a physical-looking field of days, not a progress chart. Every empty
/// cell stays visible so the color record can be read alongside the ordinary gaps.
struct SkyGridView: View {
    let year: Int
    let posts: [LocalDate: SkyPost]
    let thumbnails: [LocalDate: UIImage]
    var pendingStates: [LocalDate: PendingCellState] = [:]
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
    var isCheckingArchive = false
    var isArchiveUnavailable = false
    var onRetryArchive: (() -> Void)?

    private static let topAnchorID = "sky-grid-header"

    private var postedCount: Int { posts.count }

    var body: some View {
        ZStack {
            PlayfulStageBackdrop(accent: SGT.accentSecondary)

            ScrollViewReader { topProxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SGSpacing.xl) {
                        header
                            .id(Self.topAnchorID)
                        if isCheckingArchive || isArchiveUnavailable {
                            archiveStatusNotice
                        }
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
                }
                // Reserve resting clearance on the scroll container. Content padding
                // scrolls with the archive, while this leaves its final control above
                // the home indicator without the former tab bar's 128pt void.
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: SGSpacing.xl)
                }
                // An archive revisit should always begin at its header rather than
                // retain a prior detail scroll position.
                .onAppear { topProxy.scrollTo(Self.topAnchorID, anchor: .top) }
            }
        }
    }

    private var archiveStatusNotice: some View {
        HStack(alignment: .top, spacing: SGSpacing.md) {
            if isCheckingArchive {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SGT.ink2)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: SGSpacing.xs) {
                Text(isCheckingArchive ? "Checking your archive…" : "We couldn't refresh your archive.")
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink)
                if isArchiveUnavailable {
                    Text(posts.isEmpty ? "Your photos haven't been changed. Check your connection and try again." : "Showing the last confirmed photos on this device.")
                        .font(SGFont.caption(12))
                        .foregroundStyle(SGT.ink2)
                    if let onRetryArchive {
                        Button("Check again", action: onRetryArchive)
                            .font(SGFont.body(15))
                            .foregroundStyle(SGT.ink)
                            .frame(minHeight: 44)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SGSpacing.lg)
        .quietCard()
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .lastTextBaseline) {
                gridTitle
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: SGSpacing.md)
                gridActions
            }

            VStack(alignment: .leading, spacing: SGSpacing.md) {
                gridTitle
                gridActions
            }
        }
    }

    private var gridTitle: some View {
        VStack(alignment: .leading, spacing: SGSpacing.xs) {
            Text("SKY GRID")
                .font(SGFont.caption(11))
                .tracking(1.5)
                .foregroundStyle(SGT.ink3)
            HStack(spacing: SGSpacing.md) {
                if let onSelectPreviousYear {
                    yearButton(symbol: "chevron.left", label: "Show previous year", action: onSelectPreviousYear)
                }
                Text(String(year))
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(SGT.ink)
                MokuScreenMark(state: postedCount == 0 ? .waiting : .settled, side: 52)
                if let onSelectNextYear {
                    yearButton(symbol: "chevron.right", label: "Show next year", action: onSelectNextYear)
                }
            }
        }
    }

    private var gridActions: some View {
        VStack(alignment: .trailing, spacing: SGSpacing.md) {
            Text(isArchiveUnavailable && posts.isEmpty ? "Not checked" : "\(postedCount)")
                .font(SGFont.numeric(16, weight: .medium))
                .foregroundStyle(SGT.ink2)
                .contentTransition(.numericText())
                .skyAnimation(SGMotion.exchange, value: postedCount)
                .accessibilityLabel(
                    isArchiveUnavailable && posts.isEmpty
                        ? "Archive not checked"
                        : "\(postedCount) morning skies photographed this year"
                )
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
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.bottom, SGSpacing.sm)
    }

    private func yearButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(SGT.fill, in: Circle())
        }
        .foregroundStyle(SGT.ink2)
        .accessibilityLabel(label)
    }

    private var gridField: some View {
        VStack(spacing: SGSpacing.md) {
            dayLabels
            HStack(alignment: .center, spacing: 4) {
                monthLabels
                // A *square* block, not the grid's natural 31:12 ratio. At 31:12 the
                // year collapsed to roughly 10pt per cell — a flat grey band with a
                // thin coloured stripe through it, which made the product's signature
                // artifact look broken next to the perfectly legible month mosaic
                // directly below it. Squaring the block keeps 31 columns but gives
                // each cell ~29pt of height, so a day is a visible mark and the year
                // reads as woven texture. Cells are deliberately not square; the grid
                // is a field of days, not a chart.
                GridCanvas(
                    year: year,
                    postedDates: Set(posts.keys),
                    thumbnails: thumbnails,
                    pendingStates: pendingStates,
                    spacing: 1,
                    monthBanding: true
                )
                .aspectRatio(1, contentMode: .fit)
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
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(SGT.ink)
                }
                Spacer()
                Text(isArchiveUnavailable && posts.isEmpty ? "Not checked" : "\(monthlyPosts.count) photos")
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
                .playfulSurface(accent: SGT.accent)
            } else {
                MonthlyPhotoGrid(
                    year: year,
                    month: selectedMonth,
                    posts: posts,
                    thumbnails: thumbnails,
                    pendingStates: pendingStates,
                    onSelectPost: onSelectPost
                )
                .id(selectedMonth)
                .transition(.opacity)
                if monthlyPosts.isEmpty, !isCheckingArchive, !isArchiveUnavailable {
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
                    .font(SGFont.fixedCaption(9))
                    .foregroundStyle(SGT.ink3)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 14)
    }

    private var dayLabels: some View {
        HStack {
            Text("DAY")
                .font(SGFont.fixedCaption(9))
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
            .font(SGFont.fixedCaption(9))
            .foregroundStyle(SGT.ink3)
        }
    }
}

private struct MonthlyPhotoGrid: View {
    let year: Int
    let month: Int
    let posts: [LocalDate: SkyPost]
    let thumbnails: [LocalDate: UIImage]
    var pendingStates: [LocalDate: PendingCellState] = [:]
    let onSelectPost: (SkyPost) -> Void

    // Zero spacing on both axes: adjacent tiles abut with no gap, so the block
    // reads as one continuous pixel-art mosaic instead of a spaced-out calendar.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(GridLayoutMath.sequentialDates(year: year, month: month), id: \.self) { date in
                if let post = posts[date] {
                    Button { onSelectPost(post) } label: {
                        ArchivePhotoTile(day: date.day, thumbnail: thumbnails[date], hasPhoto: true, pendingState: nil)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open photo from \(date.docID)")
                } else if let pendingState = pendingStates[date] {
                    // Not tappable: there is no confirmed post yet to open.
                    ArchivePhotoTile(day: date.day, thumbnail: nil, hasPhoto: false, pendingState: pendingState)
                } else {
                    ArchivePhotoTile(day: date.day, thumbnail: nil, hasPhoto: false, pendingState: nil)
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
    /// Set only when this day has no confirmed post yet but does have a photo
    /// sitting in the local upload outbox — see `PendingCellState`. Mutually
    /// exclusive with `hasPhoto`/`thumbnail`: a caller never sets both.
    var pendingState: PendingCellState?

    private var isOccupied: Bool { hasPhoto || pendingState != nil }

    var body: some View {
        Rectangle()
            .fill(isOccupied ? SGT.fill : SGT.ghost)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else if hasPhoto {
                    ProgressView().controlSize(.mini)
                } else if let pendingState {
                    Image(systemName: pendingState.symbolName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SGT.ink2)
                        .accessibilityHidden(true)
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                Text(String(day))
                    .font(SGFont.fixedNumeric(10, weight: .semibold))
                    .foregroundStyle(isOccupied ? .white : SGT.ink3)
                    .shadow(radius: isOccupied ? 2 : 0)
                    .padding(4)
            }
            .accessibilityLabel(
                pendingState.map { "Day \(day), photo \($0.accessibilitySuffix)" } ?? "Day \(day)"
            )
    }
}

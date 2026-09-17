import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class GridArchiveViewModel {
    enum LoadState: Equatable {
        case checking
        case available
        case unavailable
    }

    private(set) var posts: [LocalDate: SkyPost] = [:]
    private(set) var thumbnails: [LocalDate: UIImage] = [:]
    private(set) var isPreparingShare = false
    private(set) var loadState: LoadState = .checking
    /// Days with a photo sitting in the local upload outbox but no confirmed
    /// Firestore document yet — see `PendingCellState`. Never merged into `posts`,
    /// so `postedCount`/streak/share-card reads (all sourced from `posts`) are
    /// unaffected; a date present here is guaranteed absent from `posts` by
    /// `refreshPendingStates`'s own Firestore-wins filter.
    private(set) var pendingStates: [LocalDate: PendingCellState] = [:]

    private let uid: String
    let year: Int
    private let postRepository: any PostRepository
    private let imageFetching: any ImageFetching
    private let inviteRepository: any InviteRepository
    /// Optional so existing preview/audit and test call sites that never enqueue an
    /// upload (and therefore have no outbox to reflect) don't need to construct one
    /// — matches `TodayViewModel`'s `streakSignal`/`revealSignal` optionality.
    private let uploadQueue: UploadQueue?
    private var isPro: Bool
    private let today: LocalDate
    private(set) var selectedMonth: Int
    private var observationTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?
    private var shareTask: Task<[LocalDate: UIImage]?, Never>?
    private var pendingPollTask: Task<Void, Never>?

    init(
        uid: String,
        year: Int,
        postRepository: any PostRepository,
        imageFetching: any ImageFetching,
        inviteRepository: any InviteRepository,
        uploadQueue: UploadQueue? = nil,
        isPro: Bool,
        today: LocalDate,
        selectedMonth: Int
    ) {
        self.uid = uid
        self.year = year
        self.postRepository = postRepository
        self.imageFetching = imageFetching
        self.inviteRepository = inviteRepository
        self.uploadQueue = uploadQueue
        self.isPro = isPro
        self.today = today
        self.selectedMonth = selectedMonth
    }

    func start() {
        guard observationTask == nil else { return }
        let firstDay = LocalDate(year: year, month: 1, day: 1)
        let lastDay = LocalDate(year: year, month: 12, day: 31)
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await observation in self.postRepository.observePosts(uid: self.uid, from: firstDay, through: lastDay) {
                guard case .value(let posts) = observation else {
                    self.loadState = .unavailable
                    continue
                }
                self.loadState = .available
                self.posts = Dictionary(posts.map { ($0.localDate, $0) }, uniquingKeysWith: { _, newest in newest })
                self.thumbnails = self.thumbnails.filter { self.posts[$0.key] != nil }
                self.loadVisibleThumbnails(from: posts)
                // Retire any pending overlay the instant its Firestore doc is
                // confirmed, rather than waiting up to 2s for the next poll tick —
                // this is belt-and-braces on top of `refreshPendingStates`'s own
                // filter (and the callers' render-order, which already checks
                // `posts` before `pendingStates`), so a stale entry is never even
                // reachable, not just visually shadowed.
                if !self.pendingStates.isEmpty {
                    self.pendingStates = self.pendingStates.filter { self.posts[$0.key] == nil }
                }
            }
        }

        // Uploads can only ever be pending for the current year (a capture is
        // always for "today"), so a past/future-year archive has nothing to poll
        // for — avoid spinning up a needless recurring SwiftData fetch for it.
        guard pendingPollTask == nil, uploadQueue != nil, year == today.year else { return }
        pendingPollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshPendingStates()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func retryObservation() {
        observationTask?.cancel()
        observationTask = nil
        loadState = .checking
        start()
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
        thumbnailTask?.cancel()
        thumbnailTask = nil
        shareTask?.cancel()
        shareTask = nil
        pendingPollTask?.cancel()
        pendingPollTask = nil
        isPreparingShare = false
        pendingStates = [:]
    }

    /// Polled on the same 2s cadence `TodayViewModel` already uses for its own
    /// outbox summary — cheap SwiftData fetch, no Firestore round-trip. Firestore
    /// always wins: a date that already has a confirmed `posts` entry never gets a
    /// pending overlay, regardless of what state its (now-superseded) outbox row
    /// still reports.
    private func refreshPendingStates() async {
        guard let uploadQueue else { return }
        let summaries = (try? await uploadQueue.pendingSummary()) ?? []
        var states: [LocalDate: PendingCellState] = [:]
        for summary in summaries where summary.ownerUid == uid {
            guard let date = LocalDate(docID: summary.localDateID), date.year == year else { continue }
            guard posts[date] == nil else { continue }
            states[date] = PendingCellState(uploadState: summary.state)
        }
        pendingStates = states
    }

    /// Loads every *visible* day's thumbnail for the share card. Deliberately not
    /// called on ordinary screen load — the archive stays month-lazy
    /// (`loadVisibleThumbnails`) because a year of images is this app's dominant
    /// bandwidth cost (see `ImageProcessor`). Sharing is an explicit action, so a
    /// short awaited load behind a visible button state is the right trade. Returns
    /// `nil` if cancelled (e.g. the archive left the screen mid-load).
    /// Reuses the account's existing invite link (never mints a fresh one just for a
    /// share card) — matches the pattern used everywhere else invite links are shown.
    /// Returns `nil` on any failure; callers already treat a nil invite link as
    /// "render the card without one" rather than blocking the share.
    func currentInviteLinkURL() async -> URL? {
        (try? await inviteRepository.createInvite(fresh: false))?.url
    }

    func loadThumbnailsForSharing() async -> [LocalDate: UIImage]? {
        isPreparingShare = true
        defer {
            isPreparingShare = false
            shareTask = nil
        }

        let visible = posts.values
            .filter { isPro || ProGate.isWithinFreeArchiveWindow($0.localDate, today: today) }
            .sorted { $0.localDate < $1.localDate }
        let alreadyLoaded = thumbnails

        let task = Task<[LocalDate: UIImage]?, Never> { [imageFetching] in
            var loaded: [LocalDate: UIImage] = [:]
            for post in visible {
                guard !Task.isCancelled else { return nil }
                if let cached = alreadyLoaded[post.localDate] {
                    loaded[post.localDate] = cached
                } else if let thumbnail = await Self.loadThumbnail(for: post, imageFetching: imageFetching) {
                    loaded[post.localDate] = thumbnail
                }
            }
            return loaded
        }
        shareTask = task

        guard let loaded = await task.value else { return nil }
        thumbnails = thumbnails.merging(loaded) { _, new in new }
        return loaded
    }

    func selectMonth(_ month: Int) {
        selectedMonth = month
        loadVisibleThumbnails(from: Array(posts.values))
    }

    /// Access can change while the archive remains on screen. Refresh the current
    /// month immediately instead of requiring the tab to be recreated.
    func updateAccess(isPro: Bool) {
        guard self.isPro != isPro else { return }
        self.isPro = isPro
        loadVisibleThumbnails(from: Array(posts.values))
    }

    private func loadVisibleThumbnails(from posts: [SkyPost]) {
        let pending = posts
            .filter { isPro || ProGate.isWithinFreeArchiveWindow($0.localDate, today: today) }
            .filter { $0.localDate.month == selectedMonth }
            .filter { thumbnails[$0.localDate] == nil }
            .sorted { $0.capturedAt > $1.capturedAt }
        guard !pending.isEmpty else { return }

        thumbnailTask?.cancel()
        thumbnailTask = Task { [weak self, imageFetching] in
            for post in pending {
                guard !Task.isCancelled else { return }
                let thumbnail = await Self.loadThumbnail(for: post, imageFetching: imageFetching)
                guard !Task.isCancelled else { return }
                if let thumbnail {
                    self?.thumbnails[post.localDate] = thumbnail
                }
            }
        }
    }

    private static func loadThumbnail(for post: SkyPost, imageFetching: any ImageFetching) async -> UIImage? {
        await ThumbnailLoader.loadThumbnail(forRemotePath: post.thumbPath, imageFetching: imageFetching)
    }
}

/// A live repository-backed Sky Grid. The on-screen archive deliberately renders the
/// photographs themselves; colours remain metadata for the lightweight share card.
struct GridArchiveView: View {
    @State private var viewModel: GridArchiveViewModel
    @State private var shareItem: ShareItem?
    let isPro: Bool
    let today: LocalDate
    let imageFetching: any ImageFetching
    let onUpgrade: () -> Void
    let onSelectPreviousYear: (() -> Void)?
    let onSelectNextYear: (() -> Void)?
    @State private var selectedPost: ArchivePhotoSelection?

    init(
        uid: String,
        year: Int,
        postRepository: any PostRepository,
        imageFetching: any ImageFetching,
        inviteRepository: any InviteRepository,
        uploadQueue: UploadQueue? = nil,
        isPro: Bool,
        today: LocalDate,
        onUpgrade: @escaping () -> Void,
        onSelectPreviousYear: (() -> Void)? = nil,
        onSelectNextYear: (() -> Void)? = nil
    ) {
        let initialMonth = today.year == year ? today.month : 1
        _viewModel = State(initialValue: GridArchiveViewModel(
            uid: uid,
            year: year,
            postRepository: postRepository,
            imageFetching: imageFetching,
            inviteRepository: inviteRepository,
            uploadQueue: uploadQueue,
            isPro: isPro,
            today: today,
            selectedMonth: initialMonth
        ))
        self.isPro = isPro
        self.today = today
        self.imageFetching = imageFetching
        self.onUpgrade = onUpgrade
        self.onSelectPreviousYear = onSelectPreviousYear
        self.onSelectNextYear = onSelectNextYear
    }

    var body: some View {
        SkyGridView(
            year: viewModel.year,
            posts: visiblePosts,
            thumbnails: viewModel.thumbnails,
            pendingStates: viewModel.pendingStates,
            selectedMonth: viewModel.selectedMonth,
            onSelectMonth: viewModel.selectMonth,
            onSelectPost: { selectedPost = ArchivePhotoSelection(post: $0) },
            lockedPhotoCount: lockedPhotoCount,
            canShare: !visiblePosts.isEmpty,
            onShare: shareGrid,
            isPreparingShare: viewModel.isPreparingShare,
            archiveNotice: isPro ? nil : L10n.string("archive.freeNotice"),
            onUpgrade: isPro ? nil : onUpgrade,
            onSelectPreviousYear: onSelectPreviousYear,
            onSelectNextYear: onSelectNextYear,
            isCheckingArchive: viewModel.loadState == .checking,
            isArchiveUnavailable: viewModel.loadState == .unavailable,
            onRetryArchive: viewModel.retryObservation
        )
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.image])
            }
            .sheet(item: $selectedPost) { selection in
                ArchivePhotoDetail(post: selection.post, imageFetching: imageFetching)
            }
            .task { viewModel.start() }
            .onChange(of: isPro) { _, value in
                viewModel.updateAccess(isPro: value)
            }
            .onDisappear { viewModel.stop() }
    }

    private func shareGrid() {
        guard !viewModel.isPreparingShare else { return }
        let postedDates = Set(visiblePosts.keys)
        Task {
            guard let photos = await viewModel.loadThumbnailsForSharing() else { return }
            let inviteLinkURL = await viewModel.currentInviteLinkURL()
            let image = ShareCardRenderer.render(
                year: viewModel.year,
                postedDates: postedDates,
                photos: photos,
                inviteLinkURL: inviteLinkURL
            )
            guard let image else { return }
            shareItem = ShareItem(image: image)
        }
    }

    private var visiblePosts: [LocalDate: SkyPost] {
        guard !isPro else { return viewModel.posts }
        return viewModel.posts.filter { ProGate.isWithinFreeArchiveWindow($0.key, today: today) }
    }

    private var lockedPhotoCount: Int {
        guard !isPro else { return 0 }
        return viewModel.posts.values.filter {
            $0.localDate.month == viewModel.selectedMonth && !ProGate.isWithinFreeArchiveWindow($0.localDate, today: today)
        }.count
    }
}

private struct ArchivePhotoSelection: Identifiable {
    let post: SkyPost
    var id: LocalDate { post.localDate }
}

private struct ArchivePhotoDetail: View {
    let post: SkyPost
    let imageFetching: any ImageFetching
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SGSpacing.lg) {
                    TodayPhotoCard(post: post, imageFetching: imageFetching)
                    VStack(alignment: .leading, spacing: SGSpacing.xs) {
                        Text(post.localDate.docID)
                            .font(SGFont.title(30))
                            .foregroundStyle(SGT.ink)
                        Text(String(format: L10n.string("grid.capturedAt"), post.minutesFromGoalDescription))
                            .font(SGFont.body(15))
                            .foregroundStyle(SGT.ink2)
                    }
                }
                .padding(SGSpacing.xl)
            }
            .background(MokuColor.nightStage)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Close"), action: { dismiss() })
                }
            }
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// The archive itself remains one year at a time, but Pro's “full archive” claim
/// must include previous years. Free users can also step back across New Year to
/// reach their most recent 30 days; future years are never offered.
struct SkyGridArchiveTab: View {
    private let uid: String
    private let currentYear: Int
    private let postRepository: any PostRepository
    private let imageFetching: any ImageFetching
    private let inviteRepository: any InviteRepository
    private let uploadQueue: UploadQueue?
    private let isPro: Bool
    private let today: LocalDate
    private let onUpgrade: () -> Void
    @State private var selectedYear: Int

    init(
        uid: String,
        currentYear: Int,
        postRepository: any PostRepository,
        imageFetching: any ImageFetching,
        inviteRepository: any InviteRepository,
        uploadQueue: UploadQueue? = nil,
        isPro: Bool,
        today: LocalDate,
        onUpgrade: @escaping () -> Void
    ) {
        self.uid = uid
        self.currentYear = currentYear
        self.postRepository = postRepository
        self.imageFetching = imageFetching
        self.inviteRepository = inviteRepository
        self.uploadQueue = uploadQueue
        self.isPro = isPro
        self.today = today
        self.onUpgrade = onUpgrade
        _selectedYear = State(initialValue: currentYear)
    }

    var body: some View {
        GridArchiveView(
            uid: uid,
            year: selectedYear,
            postRepository: postRepository,
            imageFetching: imageFetching,
            inviteRepository: inviteRepository,
            uploadQueue: uploadQueue,
            isPro: isPro,
            today: today,
            onUpgrade: onUpgrade,
            onSelectPreviousYear: selectedYear > 2000 ? { selectedYear -= 1 } : nil,
            onSelectNextYear: selectedYear < currentYear ? { selectedYear += 1 } : nil
        )
        .id(selectedYear)
    }
}

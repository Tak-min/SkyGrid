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

    private let uid: String
    let year: Int
    private let postRepository: any PostRepository
    private let imageFetching: any ImageFetching
    private var isPro: Bool
    private let today: LocalDate
    private(set) var selectedMonth: Int
    private var observationTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?
    private var shareTask: Task<[LocalDate: UIImage]?, Never>?

    init(
        uid: String,
        year: Int,
        postRepository: any PostRepository,
        imageFetching: any ImageFetching,
        isPro: Bool,
        today: LocalDate,
        selectedMonth: Int
    ) {
        self.uid = uid
        self.year = year
        self.postRepository = postRepository
        self.imageFetching = imageFetching
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
        isPreparingShare = false
    }

    /// Loads every *visible* day's thumbnail for the share card. Deliberately not
    /// called on ordinary screen load — the archive stays month-lazy
    /// (`loadVisibleThumbnails`) because a year of images is this app's dominant
    /// bandwidth cost (see `ImageProcessor`). Sharing is an explicit action, so a
    /// short awaited load behind a visible button state is the right trade. Returns
    /// `nil` if cancelled (e.g. the archive left the screen mid-load).
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
        if let localData = ImageFileStore.pendingImageData(forRemotePath: post.thumbPath),
           let localThumbnail = ImageProcessor.displayThumbnail(from: localData) {
            return localThumbnail
        }
        if let cachedData = ImageFileStore.cachedThumbnailData(forRemotePath: post.thumbPath),
           let cachedThumbnail = ImageProcessor.displayThumbnail(from: cachedData) {
            return cachedThumbnail
        }
        guard let remoteData = try? await imageFetching.fetchImage(path: post.thumbPath),
              let remoteThumbnail = ImageProcessor.displayThumbnail(from: remoteData)
        else { return nil }
        ImageFileStore.cacheThumbnail(remoteData, forRemotePath: post.thumbPath)
        return remoteThumbnail
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
            selectedMonth: viewModel.selectedMonth,
            onSelectMonth: viewModel.selectMonth,
            onSelectPost: { selectedPost = ArchivePhotoSelection(post: $0) },
            lockedPhotoCount: lockedPhotoCount,
            canShare: !visiblePosts.isEmpty,
            onShare: shareGrid,
            isPreparingShare: viewModel.isPreparingShare,
            archiveNotice: isPro ? nil : "Free keeps your most recent 30 days visible.",
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
            guard let photos = await viewModel.loadThumbnailsForSharing(),
                  let image = ShareCardRenderer.render(year: viewModel.year, postedDates: postedDates, photos: photos)
            else { return }
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
                            .font(SGFont.serifTitle(30))
                            .foregroundStyle(SGT.ink)
                        Text("Captured \(post.minutesFromGoalDescription)")
                            .font(SGFont.body(15))
                            .foregroundStyle(SGT.ink2)
                    }
                }
                .padding(SGSpacing.xl)
            }
            .background(SGT.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: { dismiss() })
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
    private let isPro: Bool
    private let today: LocalDate
    private let onUpgrade: () -> Void
    @State private var selectedYear: Int

    init(
        uid: String,
        currentYear: Int,
        postRepository: any PostRepository,
        imageFetching: any ImageFetching,
        isPro: Bool,
        today: LocalDate,
        onUpgrade: @escaping () -> Void
    ) {
        self.uid = uid
        self.currentYear = currentYear
        self.postRepository = postRepository
        self.imageFetching = imageFetching
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
            isPro: isPro,
            today: today,
            onUpgrade: onUpgrade,
            onSelectPreviousYear: selectedYear > 2000 ? { selectedYear -= 1 } : nil,
            onSelectNextYear: selectedYear < currentYear ? { selectedYear += 1 } : nil
        )
        .id(selectedYear)
    }
}

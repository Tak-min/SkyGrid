import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class GridArchiveViewModel {
    private(set) var colors: [LocalDate: SkyColor] = [:]

    private let uid: String
    let year: Int
    private let postRepository: any PostRepository
    private var observationTask: Task<Void, Never>?

    init(uid: String, year: Int, postRepository: any PostRepository) {
        self.uid = uid
        self.year = year
        self.postRepository = postRepository
    }

    func start() {
        guard observationTask == nil else { return }
        let firstDay = LocalDate(year: year, month: 1, day: 1)
        let lastDay = LocalDate(year: year, month: 12, day: 31)
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await posts in self.postRepository.observePosts(uid: self.uid, from: firstDay, through: lastDay) {
                self.colors = Dictionary(uniqueKeysWithValues: posts.map { ($0.localDate, $0.skyColor) })
            }
        }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
    }
}

/// A live repository-backed Sky Grid. The export uses the identical color map as the
/// on-screen grid, so a shared card is evidence from the user's real archive rather
/// than preview data.
struct GridArchiveView: View {
    @State private var viewModel: GridArchiveViewModel
    @State private var shareItem: ShareItem?
    let isPro: Bool
    let today: LocalDate
    let onUpgrade: () -> Void

    init(
        uid: String,
        year: Int,
        postRepository: any PostRepository,
        isPro: Bool,
        today: LocalDate,
        onUpgrade: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: GridArchiveViewModel(uid: uid, year: year, postRepository: postRepository))
        self.isPro = isPro
        self.today = today
        self.onUpgrade = onUpgrade
    }

    var body: some View {
        SkyGridView(
            year: viewModel.year,
            colors: visibleColors,
            canShare: !visibleColors.isEmpty,
            onShare: shareGrid,
            archiveNotice: isPro ? nil : "Free keeps your most recent 30 days visible.",
            onUpgrade: isPro ? nil : onUpgrade
        )
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.image])
            }
            .task { viewModel.start() }
            .onDisappear { viewModel.stop() }
    }

    private func shareGrid() {
        guard let image = ShareCardRenderer.render(year: viewModel.year, colors: visibleColors) else { return }
        shareItem = ShareItem(image: image)
    }

    private var visibleColors: [LocalDate: SkyColor] {
        guard !isPro else { return viewModel.colors }
        return viewModel.colors.filter { ProGate.isWithinFreeArchiveWindow($0.key, today: today) }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

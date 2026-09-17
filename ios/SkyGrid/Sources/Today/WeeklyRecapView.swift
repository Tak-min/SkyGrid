import SwiftUI
import UIKit

/// Pro-only preview of the artifact earned by completing the rolling seven-day week.
struct WeeklyRecapView: View {
    private let posts: [SkyPost]
    private let imageFetching: any ImageFetching
    private let inviteRepository: any InviteRepository
    private let onSharePresentationChanged: (Bool) -> Void
    private let onShareDismissed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var photos: [LocalDate: UIImage]
    @State private var isLoading = false
    @State private var shareImage: WeeklyRecapShareableCard?
    @State private var didRecordOpen = false

    init(
        posts: [SkyPost],
        imageFetching: any ImageFetching,
        inviteRepository: any InviteRepository,
        initialPhotos: [LocalDate: UIImage] = [:],
        onSharePresentationChanged: @escaping (Bool) -> Void = { _ in },
        onShareDismissed: @escaping () -> Void = {}
    ) {
        self.posts = Array(posts.sorted { $0.localDate < $1.localDate }.prefix(7))
        self.imageFetching = imageFetching
        self.inviteRepository = inviteRepository
        self.onSharePresentationChanged = onSharePresentationChanged
        self.onShareDismissed = onShareDismissed
        _photos = State(initialValue: initialPhotos)
    }

    var body: some View {
        ZStack {
            MokuColor.nightStage.ignoresSafeArea()
            VStack(spacing: SGSpacing.lg) {
                header
                cardPreview
                Button(action: prepareShareImage) {
                    if isLoading {
                        HStack(spacing: SGSpacing.sm) {
                            ProgressView().controlSize(.small)
                            Text("Preparing…")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("View weekly recap")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(SkyPrimaryButtonStyle())
                .disabled(isLoading)
                .accessibilityHint("Opens the share sheet with your seven-morning recap as an image")
            }
            .padding(SGSpacing.lg)
        }
        .task(id: posts.map(\.imagePath).joined(separator: ",")) {
            if !didRecordOpen {
                didRecordOpen = true
                WeeklyRecapAnalytics.record(.opened)
            }
            await loadPhotos()
        }
        .onChange(of: shareImage != nil) { _, isPresented in
            onSharePresentationChanged(isPresented)
        }
        .sheet(item: $shareImage, onDismiss: {
            onSharePresentationChanged(false)
            onShareDismissed()
        }) { card in
            ShareSheet(items: [card.image])
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Weekly recap ready")
                    .font(SGFont.caption(11))
                    .tracking(1.8)
                    .foregroundStyle(MokuColor.cloud.opacity(0.58))
                Text("Seven mornings captured")
                    .font(SGFont.body(18))
                    .fontWeight(.semibold)
                    .foregroundStyle(MokuColor.cloud)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MokuColor.cloud)
                    .frame(width: 44, height: 44)
                    .background(MokuColor.cloud.opacity(0.14), in: Circle())
            }
            .accessibilityLabel("Close")
        }
    }

    private var cardPreview: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 1080, proxy.size.height / 1920)
            WeeklyRecapExportView(
                posts: posts,
                photos: photos,
                handle: LocalDefaults.handle.flatMap(Handle.init(raw:))
            )
            .scaleEffect(scale, anchor: .center)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly recap preview with seven morning skies")
    }

    private func loadPhotos() async {
        isLoading = true
        defer { isLoading = false }
        let pipeline = DisplayImagePipeline.resolved(for: imageFetching)
        for post in posts where photos[post.localDate] == nil {
            guard !Task.isCancelled else { return }
            if let photo = await pipeline.image(path: post.imagePath, size: .photo) {
                photos[post.localDate] = photo
            }
        }
    }

    private func prepareShareImage() {
        guard !isLoading else { return }
        Task {
            let inviteLink = try? await inviteRepository.createInvite(fresh: false)
            let image = ShareCardRenderer.renderWeekly(
                posts: posts,
                photos: photos,
                handle: LocalDefaults.handle.flatMap(Handle.init(raw:)),
                inviteLinkURL: inviteLink?.url
            )
            guard let image else { return }
            shareImage = WeeklyRecapShareableCard(image: image)
            WeeklyRecapAnalytics.record(.shared)
        }
    }
}

private struct WeeklyRecapShareableCard: Identifiable {
    let image: UIImage
    let id = UUID()
}

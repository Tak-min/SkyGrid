import SwiftUI
import UIKit

/// A free, photo-first viewer for the skies that have already been mutually
/// revealed. Comparison is deliberately a separate action: opening a buddy's
/// sky should never be mistaken for a Pro gate.
struct BuddyFeedViewerView: View {
    let buddies: [TodayViewModel.BuddyStatus]
    let selectedUID: String
    let ownPost: SkyPost?
    let imageFetching: any ImageFetching
    let isPro: Bool
    let onCompare: (TodayViewModel.BuddyStatus) -> Void
    let onUpgrade: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var revealedBuddies: [TodayViewModel.BuddyStatus] {
        buddies.filter { $0.post != nil }
    }

    var body: some View {
        ZStack {
            MokuColor.nightStage.ignoresSafeArea()

            if revealedBuddies.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(revealedBuddies) { buddy in
                                BuddyFeedPageView(
                                    buddy: buddy,
                                    imageFetching: imageFetching,
                                    isPro: isPro,
                                    hasOwnPost: ownPost != nil,
                                    ownPost: ownPost,
                                    onCompare: { onCompare(buddy) },
                                    onUpgrade: onUpgrade
                                )
                                .id(buddy.uid)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .onAppear {
                        guard let selectedBuddy = revealedBuddies.first(where: { $0.uid == selectedUID }) else { return }
                        if reduceMotion {
                            proxy.scrollTo(selectedBuddy.uid, anchor: .top)
                        } else {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                proxy.scrollTo(selectedBuddy.uid, anchor: .top)
                            }
                        }
                    }
                }
            }

            // Close button - top right corner
            if !revealedBuddies.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(MokuColor.cloud)
                                .frame(width: 42, height: 42)
                                .background(Color.white.opacity(0.13), in: Circle())
                        }
                        .accessibilityLabel(L10n.string("buddy.feed.close"))
                        .padding(SGSpacing.lg)
                    }
                    Spacer()
                }
            }
        }
        .accessibilityIdentifier("buddy.feed.viewer")
    }

    private var emptyState: some View {
        VStack(spacing: SGSpacing.md) {
            MokuView(state: .waiting, side: 92)
            Text(L10n.string("buddy.feed.empty.title"))
                .font(SGFont.title(21))
                .foregroundStyle(MokuColor.cloud)
            Text(L10n.string("buddy.feed.empty.detail"))
                .font(SGFont.body(14))
                .foregroundStyle(MokuColor.cloud.opacity(0.64))
                .multilineTextAlignment(.center)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MokuColor.cloud)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.13), in: Circle())
            }
            .accessibilityLabel(L10n.string("buddy.feed.close"))
            .padding(SGSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

private struct BuddyFeedPageView: View {
    let buddy: TodayViewModel.BuddyStatus
    let imageFetching: any ImageFetching
    let isPro: Bool
    let hasOwnPost: Bool
    let ownPost: SkyPost?
    let onCompare: () -> Void
    let onUpgrade: () -> Void

    @State private var buddyPhoto: UIImage?

    private var post: SkyPost? { buddy.post }

    var body: some View {
        ZStack {
            // Full-screen photo background
            Group {
                if let buddyPhoto {
                    Image(uiImage: buddyPhoto)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [post?.skyColor.color.opacity(0.72) ?? MokuColor.nightStage,
                                 post?.skyColor.color ?? MokuColor.nightStage,
                                 MokuColor.nightStage],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .ignoresSafeArea()

            // Overlay layers
            VStack(spacing: 0) {
                // Top overlay: avatar, name, handle, time
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: SGSpacing.sm) {
                        Circle()
                            .fill(SGT.accentSecondary.opacity(0.88))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text(String(buddy.displayName.prefix(1)).uppercased())
                                    .font(SGFont.caption(14))
                                    .foregroundStyle(SGT.accentInk)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(buddy.displayName)
                                .font(SGFont.body(14))
                                .foregroundStyle(MokuColor.cloud)
                            if let post {
                                Text(post.localDate.docID)
                                    .font(SGFont.caption(11))
                                    .foregroundStyle(MokuColor.cloud.opacity(0.66))
                            }
                        }

                        Spacer()

                        if let post {
                            Text(timeLabel(post.capturedAt))
                                .font(SGFont.numeric(12, weight: .medium))
                                .foregroundStyle(MokuColor.cloud.opacity(0.72))
                        }
                    }
                    .padding(SGSpacing.lg)
                    .background(LinearGradient(
                        colors: [Color.black.opacity(0.4), Color.black.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                }

                Spacer()

                // Bottom overlay: the real comparison action and scroll hint.
                // Like/comment/share were deliberately omitted: non-functional
                // controls make a polished viewer feel unfinished.
                VStack(spacing: SGSpacing.md) {
                    HStack(spacing: SGSpacing.xl) {
                        if hasOwnPost {
                            Button {
                                if isPro { onCompare() } else { onUpgrade() }
                            } label: {
                                Label(
                                    L10n.string(isPro ? "buddy.feed.compare" : "buddy.feed.comparePro"),
                                    systemImage: isPro ? "rectangle.split.2x1" : "lock.fill"
                                )
                                .font(SGFont.body(14))
                                .foregroundStyle(MokuColor.cloud)
                                .padding(.horizontal, SGSpacing.md)
                                .frame(minHeight: 44)
                                .background(Color.black.opacity(0.34), in: Capsule())
                            }
                            .accessibilityLabel(L10n.string(isPro ? "buddy.feed.compare.accessibility" : "buddy.feed.comparePro.accessibility"))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, SGSpacing.lg)

                    // Scroll hint text
                    Text(L10n.string("buddy.feed.scrollHint"))
                        .font(SGFont.body(12))
                        .foregroundStyle(MokuColor.cloud.opacity(0.66))
                        .padding(.horizontal, SGSpacing.lg)
                        .padding(.bottom, SGSpacing.md)
                }
                .background(LinearGradient(
                    colors: [Color.black.opacity(0.1), Color.black.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .padding(.bottom, SGSpacing.lg)
            }
            .ignoresSafeArea(.all)

            // Own post thumbnail in top-right corner
            if let ownPost {
                VStack(alignment: .trailing) {
                    HStack {
                        Spacer()
                        OwnPostThumbnailView(
                            post: ownPost,
                            imageFetching: imageFetching,
                            size: 80
                        )
                        .padding(.trailing, SGSpacing.lg)
                        .padding(.top, 76)
                    }
                    Spacer()
                }
            }
        }
        .task(id: post?.imagePath) { await loadPhoto(for: post?.imagePath) }
    }

    private func loadPhoto(for path: String?) async {
        guard let path else {
            buddyPhoto = nil
            return
        }
        let loaded = await DisplayImagePipeline.resolved(for: imageFetching).image(path: path, size: .photo)
        guard !Task.isCancelled else { return }
        buddyPhoto = loaded
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }
}

private struct OwnPostThumbnailView: View {
    let post: SkyPost
    let imageFetching: any ImageFetching
    let size: CGFloat

    @State private var photo: UIImage?

    var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [post.skyColor.color.opacity(0.72), post.skyColor.color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(width: size, height: size * 1.2)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
        }
        .task(id: post.imagePath) { await loadPhoto(for: post.imagePath) }
    }

    private func loadPhoto(for path: String?) async {
        guard let path else {
            photo = nil
            return
        }
        let loaded = await DisplayImagePipeline.resolved(for: imageFetching).image(path: path, size: .thumbnail)
        guard !Task.isCancelled else { return }
        photo = loaded
    }
}

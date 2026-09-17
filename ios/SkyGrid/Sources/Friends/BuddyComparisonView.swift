import SwiftUI
import UIKit

/// Pro-only presentation of the two posts that unlocked one another today.
struct BuddyComparisonView: View {
    let ownPost: SkyPost
    let buddyPost: SkyPost
    let buddyName: String
    let imageFetching: any ImageFetching
    let inviteRepository: any InviteRepository

    @Environment(\.dismiss) private var dismiss
    @State private var ownPhoto: UIImage?
    @State private var buddyPhoto: UIImage?
    @State private var shareImage: TogetherShareableCard?

    var body: some View {
        ZStack {
            MokuColor.nightStage.ignoresSafeArea()
            VStack(spacing: SGSpacing.xl) {
                header
                HStack(spacing: SGSpacing.sm) {
                    sky(label: L10n.string("buddy.comparison.you"), post: ownPost, photo: ownPhoto)
                    sky(label: buddyName.uppercased(), post: buddyPost, photo: buddyPhoto)
                }
                .frame(maxHeight: 470)

                VStack(spacing: 4) {
                    Text("Same morning, two skies")
                        .font(SGFont.title(24))
                        .foregroundStyle(MokuColor.cloud)
                    Text("Both captured · both revealed")
                        .font(SGFont.caption(13))
                        .foregroundStyle(MokuColor.cloud.opacity(0.65))
                }

                Button(action: prepareShareImage) {
                    Label("Share together", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SkyPrimaryButtonStyle())
                .accessibilityHint("Opens the share sheet with both revealed skies")
            }
            .padding(SGSpacing.lg)
        }
        .task(id: buddyPost.imagePath) { await loadPhotos() }
        .sheet(item: $shareImage) { card in
            ShareSheet(items: [card.image])
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("TOGETHER")
                    .font(SGFont.caption(11))
                    .tracking(1.8)
                    .foregroundStyle(MokuColor.cloud.opacity(0.58))
                Text(buddyPost.localDate.docID)
                    .font(SGFont.body(15))
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

    private func sky(label: String, post: SkyPost, photo: UIImage?) -> some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            Group {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [post.skyColor.color.opacity(0.72), post.skyColor.color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(label)
                .font(SGFont.caption(11))
                .tracking(1.2)
                .foregroundStyle(MokuColor.cloud.opacity(0.65))
                .lineLimit(1)
            Text(timeLabel(post.capturedAt))
                .font(SGFont.numeric(22, weight: .semibold))
                .foregroundStyle(MokuColor.cloud)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: L10n.string("buddy.comparisonSkyAccessibility"), label, timeLabel(post.capturedAt)))
    }

    private func loadPhotos() async {
        let pipeline = DisplayImagePipeline.resolved(for: imageFetching)
        async let own = pipeline.image(path: ownPost.imagePath, size: .photo)
        async let buddy = pipeline.image(path: buddyPost.imagePath, size: .photo)
        let loaded = await (own, buddy)
        guard !Task.isCancelled else { return }
        ownPhoto = loaded.0
        buddyPhoto = loaded.1
    }

    private func prepareShareImage() {
        Task {
            let inviteLink = try? await inviteRepository.createInvite(fresh: false)
            let image = ShareCardRenderer.renderTogether(
                ownPost: ownPost,
                buddyPost: buddyPost,
                ownPhoto: ownPhoto,
                buddyPhoto: buddyPhoto,
                buddyName: buddyName,
                handle: LocalDefaults.handle.flatMap(Handle.init(raw:)),
                inviteLinkURL: inviteLink?.url
            )
            guard let image else { return }
            shareImage = TogetherShareableCard(image: image)
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }
}

private struct TogetherShareableCard: Identifiable {
    let image: UIImage
    let id = UUID()
}

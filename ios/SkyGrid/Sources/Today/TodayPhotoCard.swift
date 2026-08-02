import SwiftUI
import UIKit

/// The photo remains the record of the morning, while the time remains the visual
/// lead. A capture is shown from the local outbox before Storage has promoted it, so
/// the UI never substitutes an extracted average colour for the user's real photo.
struct TodayPhotoCard: View {
    let post: SkyPost
    let imageFetching: any ImageFetching

    @State private var image: UIImage?
    @State private var imageUnavailable = false

    var body: some View {
        // The definite frame lives on the `Rectangle`, not on a `Group` wrapping the
        // photo: a fill-mode `Image` with no width cap of its own can otherwise grow
        // its reported size to match a landscape source's aspect ratio at the fixed
        // height, pushing the whole card past its container. Putting the photo in
        // `.overlay` means it paints without ever feeding back into the card's size.
        Rectangle()
            .fill(SGT.fill)
            .frame(maxWidth: .infinity)
            .frame(height: 390)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    VStack(spacing: SGSpacing.sm) {
                        if imageUnavailable {
                            Image(systemName: "icloud.slash")
                            Text("Photo is waiting to sync")
                        } else {
                            ProgressView()
                            Text("Loading your photo")
                        }
                    }
                    .font(SGFont.caption(13))
                    .foregroundStyle(SGT.ink3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(.white.opacity(0.34), lineWidth: 1)
            }
            .accessibilityLabel("This morning's photo")
            .task(id: post.imagePath) {
                await loadImage()
            }
    }

    private func loadImage() async {
        image = nil
        imageUnavailable = false

        if let localData = ImageFileStore.pendingImageData(forRemotePath: post.imagePath),
           let localImage = UIImage(data: localData) {
            image = localImage
            return
        }

        // Once Storage has promoted a capture, its bytes never change (create-only,
        // one post per day), so a disk hit here is as trustworthy as a fresh
        // download and saves a full-resolution re-fetch on every reappearance of
        // this card (Today reappearing, or reopening the same day's archive sheet).
        if let cachedData = ImageFileStore.cachedImageData(forRemotePath: post.imagePath),
           let cachedImage = UIImage(data: cachedData) {
            image = cachedImage
            return
        }

        // Firestore metadata can arrive before the Storage object. Keep this task
        // alive with a capped backoff so a successful background upload replaces
        // the neutral state without requiring a screen reload.
        var retryDelay: UInt64 = 500_000_000
        while !Task.isCancelled {
            if let data = try? await imageFetching.fetchImage(path: post.imagePath),
               let loaded = UIImage(data: data) {
                guard !Task.isCancelled else { return }
                ImageFileStore.cacheImage(data, forRemotePath: post.imagePath)
                image = loaded
                return
            }
            imageUnavailable = true
            try? await Task.sleep(nanoseconds: retryDelay)
            retryDelay = min(retryDelay * 2, 8_000_000_000)
        }
    }
}

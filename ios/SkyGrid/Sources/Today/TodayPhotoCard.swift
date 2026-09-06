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
    /// True while `image` holds the cached low-resolution thumbnail rather than the
    /// promoted photo. Without it the preview silently replaced the waiting-to-sync
    /// state and a blurred 320px tile stood in as the finished morning indefinitely.
    @State private var isPreview = false

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
                        .overlay(alignment: .bottom) {
                            if isPreview {
                                Label("Photo is waiting to sync", systemImage: "icloud.slash")
                                    .font(SGFont.caption(12))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, SGSpacing.md)
                                    .padding(.vertical, SGSpacing.xs)
                                    // Sits directly on the user's own sky photo, which
                                    // can be a bright overexposed morning — 42% black
                                    // let enough of it through to fall under 4.5:1.
                                    .background(.black.opacity(0.68), in: Capsule())
                                    .padding(.bottom, SGSpacing.md)
                            }
                        }
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
            // One stop, not two: the sync badge is part of the photo's state, and
            // the rest of this screen groups its composite regions the same way.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isPreview ? "This morning's photo, waiting to sync" : "This morning's photo")
            .task(id: post.imagePath) {
                await loadImage()
            }
    }

    private func loadImage() async {
        image = nil
        imageUnavailable = false
        isPreview = false
        let pipeline = DisplayImagePipeline.resolved(for: imageFetching)

        // Firestore metadata can arrive before the Storage object. Keep this task
        // alive with a capped backoff so a successful background upload replaces
        // the neutral state without requiring a screen reload.
        var retryDelay: UInt64 = 500_000_000
        while !Task.isCancelled {
            if let loaded = await pipeline.image(path: post.imagePath, size: .photo) {
                guard !Task.isCancelled else { return }
                image = loaded
                isPreview = false
                return
            }
            // A thumbnail already cached by the mosaic makes a useful progressive
            // preview while the full image is unavailable. No extra remote fetch.
            if image == nil {
                // Through the pipeline, not `ImageFileStore` directly: revocation is
                // the pipeline's to enforce, and `cachedImage` never falls back to a
                // remote fetch, so this stays free.
                let preview = await pipeline.cachedImage(path: post.thumbPath, size: .thumbnail)
                guard !Task.isCancelled else { return }
                if let preview {
                    image = preview
                    isPreview = true
                }
            }
            imageUnavailable = true
            try? await Task.sleep(nanoseconds: retryDelay)
            retryDelay = min(retryDelay * 2, 8_000_000_000)
        }
    }
}

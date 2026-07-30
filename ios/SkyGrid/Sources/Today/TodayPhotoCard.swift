import SwiftUI
import UIKit

/// The photo remains the record of the morning, while the time remains the visual
/// lead. Until the upload queue promotes local bytes, the extracted sky color gives
/// the card a quiet, stable fallback instead of a spinner or an error state.
struct TodayPhotoCard: View {
    let post: SkyPost
    let imageFetching: any ImageFetching

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(post.skyColor.color)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 390)
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
        // The local uploader needs a brief moment to promote its files. Retrying a
        // handful of times avoids a visible race immediately after confirmation.
        for attempt in 0..<3 {
            if let data = try? await imageFetching.fetchImage(path: post.imagePath),
               let loaded = UIImage(data: data) {
                image = loaded
                return
            }
            guard attempt < 2 else { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
}

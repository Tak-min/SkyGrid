import SwiftUI
import UIKit

/// The pre-capture card looks back exactly one morning when that photo is available.
/// It deliberately uses the shared thumbnail loader rather than fetching a full-size
/// image: yesterday's thumbnail is already the right crop for this small, treated
/// backdrop and inherits the app's local-cache → remote-fetch → cache path.
struct YesterdaySkyBackdrop: View {
    let thumbPath: String?
    let imageFetching: any ImageFetching
    let fallback: LinearGradient

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            fallback

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .saturation(0.62)
                    .brightness(-0.18)

                // A photograph brings the ritual back into view, while this scrim
                // keeps the streak number equally legible across bright skies.
                LinearGradient(
                    colors: [.black.opacity(0.46), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                // Day one and a failed thumbnail load retain the previous visual
                // rather than exposing a blank or a loading error in the hero.
                Circle()
                    .fill(.white.opacity(0.24))
                    .frame(width: 168, height: 168)
                    .blur(radius: 2)
                    .offset(x: 28, y: -36)

                LinearGradient(
                    colors: [.black.opacity(0.65), .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(.white.opacity(0.32), lineWidth: 1)
        }
        .accessibilityHidden(true)
        .task(id: thumbPath) { await loadThumbnail(for: thumbPath) }
    }

    private func loadThumbnail(for path: String?) async {
        guard let path else {
            thumbnail = nil
            return
        }
        let loaded = await ThumbnailLoader.loadThumbnail(forRemotePath: path, imageFetching: imageFetching)
        guard !Task.isCancelled else { return }
        thumbnail = loaded
    }
}

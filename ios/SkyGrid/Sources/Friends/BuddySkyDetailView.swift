import SwiftUI

/// Opens an already-revealed buddy sky at full size.
///
/// The buddies list only ever showed `thumbPath` inside a 42pt avatar, so the
/// thing both people got up for — the other person's actual morning — was never
/// visible. This presents `imagePath` on the night stage, the same ground the
/// camera and reward surfaces use when the photograph is the content.
///
/// Reveal permission is not decided here. The caller may only construct this
/// from a `.posted` state, which already carries a post returned by the
/// server-authoritative buddy read; this view performs no additional read and
/// cannot widen what the server allowed.
struct BuddySkyDetailView: View {
    let post: SkyPost
    let displayName: String
    let handle: String?
    let imageFetching: any ImageFetching

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?
    @State private var imageUnavailable = false
    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1

    private static let maxZoom: CGFloat = 4

    var body: some View {
        ZStack {
            MokuColor.nightStage.ignoresSafeArea()
            content
            closeButton
        }
        .task(id: post.imagePath) { await load() }
    }

    private var content: some View {
        VStack(spacing: SGSpacing.md) {
            Spacer(minLength: 0)
            photo
            caption
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SGSpacing.md)
    }

    @ViewBuilder
    private var photo: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(zoom)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .gesture(magnification)
                .onTapGesture(count: 2) { toggleZoom() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: L10n.string("buddy.skyThisMorningAccessibility"), displayName))
                .accessibilityHint("Double tap to zoom")
        } else {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(SGT.ghostFaint)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    VStack(spacing: SGSpacing.sm) {
                        if imageUnavailable {
                            // A missing sky stays visibly missing. Never stand in
                            // a colour swatch and let it read as their morning.
                            Image(systemName: "icloud.slash")
                            Text("This sky could not be loaded")
                        } else {
                            ProgressView()
                            Text("Loading their sky")
                        }
                    }
                    .font(SGFont.caption(13))
                    .foregroundStyle(MokuColor.cloud.opacity(0.7))
                }
        }
    }

    private var caption: some View {
        VStack(spacing: 2) {
            Text(displayName)
                .font(SGFont.body(16))
                .foregroundStyle(MokuColor.cloud)
            if let handle {
                Text("@" + handle)
                    .font(SGFont.caption(13))
                    .foregroundStyle(MokuColor.cloud.opacity(0.6))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MokuColor.cloud)
                        .frame(width: 44, height: 44)
                        .background(MokuColor.cloud.opacity(0.14), in: Circle())
                }
                .accessibilityLabel("Close")
            }
            Spacer()
        }
        .padding(SGSpacing.md)
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = clamped(committedZoom * value.magnification)
            }
            .onEnded { _ in
                committedZoom = zoom
            }
    }

    private func toggleZoom() {
        let target: CGFloat = committedZoom > 1 ? 1 : 2
        if reduceMotion {
            zoom = target
        } else {
            withAnimation(SGMotion.settle) { zoom = target }
        }
        committedZoom = target
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), Self.maxZoom)
    }

    private func load() async {
        image = nil
        imageUnavailable = false
        let pipeline = DisplayImagePipeline.resolved(for: imageFetching)
        let loaded = await pipeline.image(path: post.imagePath, size: .photo)
        guard !Task.isCancelled else { return }
        if let loaded {
            image = loaded
        } else {
            imageUnavailable = true
        }
    }
}

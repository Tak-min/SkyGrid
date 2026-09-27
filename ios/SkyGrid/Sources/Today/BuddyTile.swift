import SwiftUI
import UIKit

/// A buddy's tile shows their actual morning photo once revealed.
///
/// **Design history (updated 2026-08-14):** this used to show only the extracted sky
/// colour, never the photo — the app's founding design pillar was "the star isn't the
/// photo, it's the numbers" (`VISION.md` §6). The product owner reversed that decision
/// after real-device testing confirmed color-only felt thin; the reversal is
/// deliberate and covers every screen, not just this one (see
/// `dev-notes/photo-over-color-conversion_2026-08-14.md`). The mutual-reveal *privacy
/// gate* is unchanged — only what renders once a buddy's post is already readable
/// changed from colour to photo. The backend already supported this: `imageDownloadURL`
/// (`ios/functions/src/index.ts`) gates a buddy's photo bytes behind the exact same
/// `isActiveBuddy && hasPostedToday` check `firestore.rules` uses for the post
/// document itself, so no privacy boundary moved — this view just started asking for
/// bytes it was always allowed to request.
///
/// The three states still map onto what the client is *allowed to know*
/// (`TodayViewModel.BuddyRevealState`), which is a server fact, not a styling choice:
/// `firestore.rules` denies buddy post reads until the viewer has posted. So before
/// capture the tile must show sealed suspense — it deliberately does **not** say "not
/// yet", because at that point the app genuinely cannot tell the difference between a
/// buddy who slept in and one who was up before you.
///
/// What's sealed here is the *content* — not the *fact* of a post. A buddy-post push
/// notification (`onBuddyPostCreated`) tells the viewer out of band that a buddy
/// captured this morning, without revealing anything about their sky; this tile still
/// shows sealed suspense until the viewer posts too. The two are deliberately
/// different channels: this view answers "what can I show", the push answers "should
/// I go remind you to look."
struct BuddyTile: View {
    enum Style {
        case compact
        case featured
    }

    let displayName: String
    let revealState: TodayViewModel.BuddyRevealState
    let streak: BuddyStreakDisplayPolicy.Display?
    let imageFetching: any ImageFetching
    var style: Style = .compact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var thumbnail: UIImage?
    // Drives the sealed tile's slow "breathing" glow (see the sealed overlay
    // below). A plain `@State` toggled in `.onAppear`, not a value-based
    // `.animation(value:)` trigger tied to `revealState`, because the pulse must
    // keep repeating for as long as the tile stays sealed, not just once per
    // state transition.
    @State private var isSealedPulsing = false

    private var isPosted: Bool {
        if case .posted = revealState { return true }
        return false
    }

    var body: some View {
        Group {
            switch style {
            case .compact:
                compactContent
            case .featured:
                featuredContent
            }
        }
        .animation(reduceMotion ? nil : SGMotion.settle, value: revealState)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .task(id: photoIdentity) { await loadThumbnail(for: photoIdentity) }
    }

    private var compactContent: some View {
        VStack(spacing: 6) {
            skyArtwork(width: 58, height: 58, cornerRadius: 29, isCircle: true)
            Text(caption)
                .font(SGFont.caption(11))
                .foregroundStyle(SGT.ink3)
                .lineLimit(1)
            if let streak {
                Text(streak.text)
                    .font(SGFont.numeric(10, weight: .medium))
                    .foregroundStyle(SGT.ink2)
                    .lineLimit(1)
            }
        }
    }

    /// A larger, photo-first tile for Today. The circle avatar implied a social
    /// profile; the morning sky is the relationship, so give it enough surface to
    /// read as a real post and make the tap affordance obvious.
    private var featuredContent: some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            skyArtwork(width: 148, height: 132, cornerRadius: 18, isCircle: false)
            HStack(alignment: .firstTextBaseline, spacing: SGSpacing.xs) {
                Text(caption)
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isPosted {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SGT.ink3)
                        .accessibilityHidden(true)
                }
            }
            if let streak {
                Text(streak.text)
                    .font(SGFont.numeric(11, weight: .medium))
                    .foregroundStyle(SGT.ink2)
                    .lineLimit(1)
            }
        }
        .padding(SGSpacing.sm)
        .frame(width: 172, alignment: .leading)
        .background(SGT.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isPosted ? SGT.accentSecondary.opacity(0.48) : SGT.rule.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    @ViewBuilder
    private func skyArtwork(width: CGFloat, height: CGFloat, cornerRadius: CGFloat, isCircle: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: isCircle ? min(width, height) / 2 : cornerRadius, style: .continuous)
        shape
            .fill(tileFill)
            .frame(width: width, height: height)
            .overlay {
                // Gated on `isPosted`, not just `thumbnail != nil`: a fetched photo
                // must never keep showing once `revealState` reverts to `.sealed`.
                if isPosted, let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipShape(shape)
                }
            }
            .overlay(shape.strokeBorder(strokeColor, lineWidth: 1))
            .overlay {
                if case .sealed = revealState {
                    ZStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: style == .featured ? 19 : 15, weight: .semibold))
                            .foregroundStyle(SGT.ink3.opacity(0.35))
                            .blur(radius: 4)
                        Image(systemName: "lock.fill")
                            .font(.system(size: style == .featured ? 19 : 15, weight: .semibold))
                            .foregroundStyle(SGT.ink3)
                            .opacity(isSealedPulsing ? 1 : 0.85)
                    }
                    .scaleEffect(isSealedPulsing ? 1.03 : 1)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                            isSealedPulsing = true
                        }
                    }
                }
            }
            .scaleEffect(isPosted ? 1 : 0.96)
    }

    /// `nil` while sealed/not-yet. `.task(id:)` cancels and restarts whenever this
    /// value changes — including the transition *to* `nil` (a revert to `.sealed`),
    /// which is what makes `loadThumbnail(for:)` clear a stale photo rather than
    /// leaving one behind. Two posted states sharing the same `thumbPath` are treated
    /// as identical and do not re-trigger a fetch.
    private var photoIdentity: String? {
        guard case .posted(let post) = revealState else { return nil }
        return post.thumbPath
    }

    /// `identity` is the value `.task(id:)` captured when *this* task instance was
    /// started — reading it as a parameter rather than re-deriving `photoIdentity`
    /// from `revealState` inside the closure matters because `revealState` is a plain
    /// `let` on this value-type `View`: a later re-render produces a *new* `BuddyTile`
    /// struct, so `self.revealState` inside an already-running task is frozen to
    /// whatever it was when the task started and can never reflect a newer render. The
    /// only *live* signal available inside a suspended task is `Task.isCancelled`,
    /// which SwiftUI sets the instant `.task(id:)`'s id changes — checking it after the
    /// `await` (mirroring `GridArchiveViewModel.loadThumbnail`'s callers) is what
    /// actually discards a stale, still-in-flight fetch instead of the tautological
    /// re-check this used to have.
    private func loadThumbnail(for identity: String?) async {
        guard let identity else {
            thumbnail = nil
            return
        }
        let loaded = await ThumbnailLoader.loadThumbnail(forRemotePath: identity, imageFetching: imageFetching)
        guard !Task.isCancelled else { return }
        thumbnail = loaded
    }

    /// The colour fallback: while the photo is loading, and — permanently, not just
    /// transiently — if the fetch fails (offline, the buddy revoked the pairing
    /// mid-load, App Check rejection). `post.skyColor` remains a real, server-verified
    /// fact about that exact morning even when the photo bytes cannot be shown, so it
    /// is a legitimate degrade rather than an invented placeholder.
    /// `.sealed` retains a faint fill for hidden posted content, while `.notYet` uses the established empty-day token.
    private var tileFill: AnyShapeStyle {
        switch revealState {
        case .posted(let post):
            AnyShapeStyle(post.skyColor.color)
        case .sealed:
            // A radial gradient between the same two existing ghost tokens reads
            // as gentle depth rather than the flat single-color fill this used to
            // be — no new tokens, just a different combination of the ones this
            // file already uses.
            AnyShapeStyle(RadialGradient(colors: [SGT.ghostFaint, SGT.ghost], center: .center, startRadius: 4, endRadius: 34))
        case .notYet:
            AnyShapeStyle(SGT.ghost)
        }
    }

    private var strokeColor: Color {
        switch revealState {
        case .posted:
            SGT.ink.opacity(0.14)
        case .sealed, .notYet:
            SGT.rule
        }
    }

    private var caption: String {
        switch revealState {
        case .posted, .sealed:
            displayName
        case .notYet:
            String(format: L10n.string("buddy.tile.notYetSuffix"), displayName)
        }
    }

    private var accessibilityLabel: String {
        let revealLabel: String = switch revealState {
        case .posted:
            String(format: L10n.string("buddy.tile.accessibilityLabel.revealed"), displayName)
        case .sealed:
            String(format: L10n.string("buddy.tile.accessibilityLabel.sealed"), displayName)
        case .notYet:
            String(format: L10n.string("buddy.tile.accessibilityLabel.notYet"), displayName)
        }
        return [revealLabel, streak?.accessibilityLabel].compactMap { $0 }.joined(separator: ". ")
    }
}

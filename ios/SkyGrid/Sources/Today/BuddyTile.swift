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
    let displayName: String
    let revealState: TodayViewModel.BuddyRevealState
    let imageFetching: any ImageFetching
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var thumbnail: UIImage?

    private var isPosted: Bool {
        if case .posted = revealState { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(tileFill)
                .frame(width: 58, height: 58)
                .overlay {
                    // Gated on `isPosted`, not just `thumbnail != nil`: a fetched photo
                    // must never keep showing once `revealState` reverts to `.sealed`
                    // (e.g. `recoverOrphanedPost()` clears the viewer's own post, which
                    // re-seals every buddy on the next refresh — see
                    // `TodayViewModel.performRefreshBuddies`). `photoIdentity`'s `.task`
                    // below already clears `thumbnail` on that same transition; this is
                    // belt-and-suspenders so a stale render can never leak through even
                    // if that clearing is ever skipped or racing.
                    if isPosted, let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 58, height: 58)
                            .clipShape(Circle())
                    }
                }
                .overlay(Circle().strokeBorder(strokeColor, lineWidth: 1))
                .overlay {
                    if case .sealed = revealState {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SGT.ink3)
                    }
                }
                .scaleEffect(isPosted ? 1 : 0.92)
            Text(caption)
                .font(SGFont.caption(11))
                .foregroundStyle(SGT.ink3)
                .lineLimit(1)
        }
        .animation(reduceMotion ? nil : SGMotion.settle, value: revealState)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .task(id: photoIdentity) { await loadThumbnail(for: photoIdentity) }
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
    private var tileFill: AnyShapeStyle {
        switch revealState {
        case .posted(let post):
            AnyShapeStyle(post.skyColor.color)
        case .sealed, .notYet:
            AnyShapeStyle(SGT.ghostFaint)
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
            "\(displayName) · not yet"
        }
    }

    private var accessibilityLabel: String {
        switch revealState {
        case .posted:
            "\(displayName), sky revealed"
        case .sealed:
            "\(displayName), sealed until you capture this morning"
        case .notYet:
            "\(displayName), hasn't captured yet"
        }
    }
}

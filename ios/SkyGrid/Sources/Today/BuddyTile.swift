import SwiftUI

/// A buddy's tile shows only their sky colour, never the photo itself.
///
/// The three states map exactly onto what the client is *allowed to know*
/// (`TodayViewModel.BuddyRevealState`), which is a server fact, not a styling
/// choice: `firestore.rules` denies buddy post reads until the viewer has posted.
/// So before capture the tile must show sealed suspense — it deliberately does
/// **not** say "not yet", because at that point the app genuinely cannot tell the
/// difference between a buddy who slept in and one who was up before you.
///
/// What's sealed here is the *content* (the sky colour) — not the *fact* of a post.
/// A buddy-post push notification (`onBuddyPostCreated`) tells the viewer out of
/// band that a buddy captured this morning, without revealing anything about their
/// sky; this tile still shows sealed suspense until the viewer posts too. The two
/// are deliberately different channels: this view answers "what can I show", the
/// push answers "should I go remind you to look."
struct BuddyTile: View {
    let displayName: String
    let revealState: TodayViewModel.BuddyRevealState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isPosted: Bool {
        if case .posted = revealState { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(tileFill)
                .frame(width: 58, height: 58)
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
    }

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

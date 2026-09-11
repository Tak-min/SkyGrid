import SwiftUI
import UIKit

/// The loud half of the persona split (`VISION.md` §6, revised 2026-08-08): the 6am
/// capture stays quiet, and this — a rare, earned, explicitly shareable moment — is
/// where the app finally raises its voice.
///
/// The hero is a **live** `MorningCardExportView` at its true 1080×1920, scaled to
/// fit (the technique `ShareCardAuditView` already uses). That is deliberate: what
/// the user sees here is byte-identical to what the share button produces, so the
/// preview is the product rather than an approximation of it.
struct MilestoneView: View {
    let moment: MilestoneMoment
    let inviteRepository: any InviteRepository
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @State private var shareImage: ShareableCard?

    var body: some View {
        ZStack {
            PlayfulStageBackdrop(accent: moment.post.skyColor.color)

            VStack(spacing: SGSpacing.xl) {
                headline
                cardPreview
                actions
            }
            .padding(.horizontal, SGSpacing.xl)
            .padding(.vertical, SGSpacing.xxl)
        }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.94)
        .task {
            Haptics.milestoneReached()
            SoundEffectPlayer.shared.play(.streakMilestone)
            // Reduce Motion still gets the state change, just without the spring —
            // skipping the assignment entirely would leave the screen invisible.
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(SGMotion.settle) { hasAppeared = true }
            }
        }
        .sheet(item: $shareImage) { card in
            ShareSheet(items: [card.image])
        }
    }

    private var headline: some View {
        VStack(spacing: SGSpacing.sm) {
            Text(moment.milestone.title)
                .font(SGFont.display(64))
                .foregroundStyle(SGT.ink)
            HStack(spacing: SGSpacing.sm) {
                Text(moment.milestone.headline)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                MokuScreenMark(state: .delight, side: 54)
            }
                .foregroundStyle(SGT.ink2)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(moment.milestone.title). \(moment.milestone.headline)")
    }

    private var cardPreview: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 1080, proxy.size.height / 1920)
            MorningCardExportView(
                post: moment.post,
                photo: moment.photo,
                streak: moment.milestone.streak,
                handle: moment.handle
            )
            .frame(width: 1080, height: 1920)
            .scaleEffect(scale, anchor: .center)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        }
        // The card restates the headline and the streak, so exposing its internals
        // would make VoiceOver read the same milestone three times.
        .accessibilityHidden(true)
    }

    private var actions: some View {
        VStack(spacing: SGSpacing.md) {
            Button("Share this morning") { prepareShareImage() }
                .buttonStyle(SkyPrimaryButtonStyle())
                .accessibilityHint("Opens the share sheet with this card as an image")

            // Bet 3 (dev-note §7 P0): a person already excited enough to be looking at
            // a milestone is the cheapest place to test whether invite *placement*,
            // not desire, was the binding constraint — see the Buddies-tab-only
            // version of this same card. Only shown once a handle exists, matching
            // the gate `InviteLinkCard`'s own doc comment describes; `moment.handle`
            // is already resolved by the presenter, so no extra fetch is needed here.
            if moment.handle != nil {
                // The dark colour scheme is already applied to the whole view in
                // `body` — no need to reassert it here.
                InviteLinkCard(inviteRepository: inviteRepository, placement: .milestone)
            }

            Button("Done", action: onDone)
                .font(SGFont.body(16))
                .foregroundStyle(SGT.ink2)
        }
    }

    /// Rendering is synchronous and happens on demand rather than on appear, so the
    /// moment shows instantly and a user who never taps Share never pays for a
    /// 1080×1920 rasterisation.
    private func prepareShareImage() {
        guard let image = ShareCardRenderer.renderMorning(
            post: moment.post,
            photo: moment.photo,
            streak: moment.milestone.streak,
            handle: moment.handle
        ) else { return }
        shareImage = ShareableCard(image: image)
        MorningShareAnalytics.record(.shared, placement: .milestone)
    }
}

/// `sheet(item:)` needs an `Identifiable`. Wrapped locally rather than conforming
/// `UIImage` itself, which would be a retroactive conformance on a UIKit type visible
/// to the whole module.
private struct ShareableCard: Identifiable {
    let image: UIImage
    let id = UUID()
}

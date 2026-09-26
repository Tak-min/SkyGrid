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
        GeometryReader { outerProxy in
            // Everything — headline, hero card, and both CTAs — lives in one
            // ScrollView's natural flow, nothing pinned via `.safeAreaInset`.
            // Three earlier attempts (see VISION.md Ticket 9 progress notes,
            // each verified with a real Simulator screenshot) tried pinning the
            // Share button at the bottom while the card/`InviteLinkCard` stayed
            // scrollable: every attempt let scrollable content render underneath
            // the pinned overlay at scroll position 0, because `.safeAreaInset`
            // does not clip the ScrollView's own viewport — it only lets the
            // user scroll past the pinned bar, it does not prevent content
            // earlier in the flow from occupying the same on-screen band as a
            // fixed-position overlay. A fully scrollable, unpinned layout has no
            // such fixed-position band to collide with.
            //
            // `outerProxy.size` is captured once and reused for `cardPreview`'s
            // width; that's only safe because this app is iPhone-only and
            // portrait-only (`TARGETED_DEVICE_FAMILY: "1"`, `UISupportedInterface
            // Orientations: Portrait` in `project.yml`). If landscape, iPad, or a
            // resizable/multitasking window ever gets added, this needs to react
            // to `outerProxy.size` changing after first layout, not just reading
            // it once.
            ScrollView(showsIndicators: false) {
                VStack(spacing: SGSpacing.xl) {
                    headline
                    cardPreview(availableWidth: outerProxy.size.width - SGSpacing.xl * 2)

                    Button("Share this morning") { prepareShareImage() }
                        .buttonStyle(SkyPrimaryButtonStyle())
                        .accessibilityHint("Opens the share sheet with this card as an image")

                    // Bet 3 (dev-note §7 P0): a person already excited enough to be
                    // looking at a milestone is the cheapest place to test whether
                    // invite *placement*, not desire, was the binding constraint —
                    // see the Buddies-tab-only version of this same card. Only shown
                    // once a handle exists, matching the gate `InviteLinkCard`'s own
                    // doc comment describes; `moment.handle` is already resolved by
                    // the presenter, so no extra fetch is needed here.
                    if moment.handle != nil {
                        InviteLinkCard(inviteRepository: inviteRepository, placement: .milestone)
                    }

                    Button("Done", action: onDone)
                        .buttonStyle(SkySecondaryButtonStyle())
                }
                .padding(.horizontal, SGSpacing.xl)
                .padding(.vertical, SGSpacing.xxl)
                .frame(maxWidth: .infinity)
            }
            .background(PlayfulStageBackdrop(accent: moment.post.skyColor.color).ignoresSafeArea())
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
        VStack(spacing: SGSpacing.md) {
            Text(moment.milestone.title)
                .font(SGFont.display(68, weight: .black))
                .tracking(-0.8)
                .foregroundStyle(SGT.ink)
            HStack(spacing: SGSpacing.sm) {
                Text(moment.milestone.headline)
                    .font(SGFont.body(18))
                    .fontWeight(.semibold)
                MokuScreenMark(state: .delight, side: 48)
            }
                .foregroundStyle(SGT.ink2)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(moment.milestone.title). \(moment.milestone.headline)")
    }

    private func cardPreview(availableWidth: CGFloat) -> some View {
        // Fill the available width so the hero card reads as dominant per
        // DESIGN.md's ENERGY 4/5 dial; height follows the card's fixed 1080:1920
        // aspect ratio. The whole screen is one ScrollView with nothing pinned
        // (see `body`), so a card taller than one device's screen is fine — the
        // user scrolls, same as reaching the "Invite a buddy" card and Done
        // button beneath it.
        let scale = availableWidth / 1080
        return MorningCardExportView(
            post: moment.post,
            photo: moment.photo,
            streak: moment.milestone.streak,
            handle: moment.handle
        )
        .frame(width: 1080, height: 1920)
        .scaleEffect(scale, anchor: .center)
        .frame(width: availableWidth, height: 1920 * scale)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        // The card restates the headline and the streak, so exposing its internals
        // would make VoiceOver read the same milestone three times.
        .accessibilityHidden(true)
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

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
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @State private var shareImage: ShareableCard?

    var body: some View {
        ZStack {
            SGExport.ground.ignoresSafeArea()

            VStack(spacing: SGSpacing.xl) {
                headline
                cardPreview
                actions
            }
            .padding(.horizontal, SGSpacing.xl)
            .padding(.vertical, SGSpacing.xxl)
        }
        .environment(\.colorScheme, .dark)
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.94)
        .task {
            Haptics.milestoneReached()
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
                .foregroundStyle(SGExport.ink)
            Text(moment.milestone.headline)
                .font(SGFont.serifTitle(20))
                .foregroundStyle(SGExport.ink2)
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
            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
        }
        // The card restates the headline and the streak, so exposing its internals
        // would make VoiceOver read the same milestone three times.
        .accessibilityHidden(true)
    }

    private var actions: some View {
        VStack(spacing: SGSpacing.md) {
            Button("Share this morning") { prepareShareImage() }
                .buttonStyle(SkyLoudButtonStyle())
                .accessibilityHint("Opens the share sheet with this card as an image")

            Button("Done", action: onDone)
                .font(SGFont.body(16))
                .foregroundStyle(SGExport.ink2)
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
    }
}

/// `sheet(item:)` needs an `Identifiable`. Wrapped locally rather than conforming
/// `UIImage` itself, which would be a retroactive conformance on a UIKit type visible
/// to the whole module.
private struct ShareableCard: Identifiable {
    let image: UIImage
    let id = UUID()
}

import SwiftUI

/// The "what is this, and how do I get it" block shared by both share cards.
///
/// It replaced a QR code on 2026-08-11. These cards are built to be posted to an
/// Instagram/TikTok Story, and a Story is watched on the same phone that would
/// have to scan the code — a phone cannot point its camera at its own screen. The
/// QR was therefore unreachable for the exact audience the card is aimed at, while
/// occupying the largest block in the footer.
///
/// Restyled the same day, because the replacement had the opposite failure: a small
/// icon and two lines of text in the bottom-left corner reads as a *watermark*, i.e.
/// as something to ignore. It is now a full-width ticket on a raised surface, ending
/// in the only instruction that is actually true on a Story — **search**. A Story
/// image cannot carry a tappable link, so "search" is the honest call to action; it is
/// deliberately not drawn as a button, because a fake button that does nothing when
/// tapped is worse than no button.
///
/// The filename ends in `ExportView` on purpose — that is what keeps this inside
/// the `SGExport` boundary allowlist documented in `DesignSystem/ExportTheme.swift`.
struct AppStoreIdentity: View {
    let handle: Handle?

    private static let cornerRadius: CGFloat = 32

    var body: some View {
        HStack(spacing: 24) {
            Image("ExportAppIcon")
                .resizable()
                .frame(width: 112, height: 112)
                // iOS masks its icons with a continuous squircle of roughly 17.5%
                // of the side, so a bare square here would read as the wrong app.
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                if let handle {
                    // Labelled rather than a bare "@name", so the person who shared
                    // the card cannot be mistaken for the app's own account.
                    Text(String(format: L10n.string("export.sharedByHandle"), handle.value))
                        .font(SGFont.fixedNumeric(20, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(SGExport.inkMuted)
                }
                Text("Sky Grid")
                    .font(SGFont.fixedSerifTitle(46))
                    .foregroundStyle(SGExport.ink)
                Text("on the App Store")
                    .font(SGFont.fixedCaption(24))
                    .foregroundStyle(SGExport.inkMuted)
            }

            Spacer(minLength: 18)

            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34, weight: .semibold))
                Text("SEARCH")
                    .font(SGFont.fixedCaption(18))
                    .tracking(3)
            }
            .foregroundStyle(SGExport.ink)
            .frame(width: 100)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .frame(height: 168)
        .background(SGExport.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(SGExport.hairline, lineWidth: 2)
        }
    }
}

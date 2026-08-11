import SwiftUI

/// The "what is this, and how do I get it" block shared by both share cards.
///
/// It replaced a QR code on 2026-08-11. These cards are built to be posted to an
/// Instagram/TikTok Story, and a Story is watched on the same phone that would
/// have to scan the code — a phone cannot point its camera at its own screen. The
/// QR was therefore unreachable for the exact audience the card is aimed at, while
/// occupying the largest block in the footer. The icon and the name are things a
/// viewer can act on directly: recognise the mark, then search the name.
///
/// The filename ends in `ExportView` on purpose — that is what keeps this inside
/// the `SGExport` boundary allowlist documented in `DesignSystem/ExportTheme.swift`.
struct AppStoreIdentity: View {
    let handle: Handle?

    var body: some View {
        HStack(spacing: 24) {
            Image("ExportAppIcon")
                .resizable()
                .frame(width: 132, height: 132)
                // iOS masks its icons with a continuous squircle of roughly 17.5%
                // of the side, so a bare square here would read as the wrong app.
                .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                if let handle {
                    Text("@\(handle.value)")
                        .font(SGFont.fixedNumeric(28, weight: .semibold))
                        .foregroundStyle(SGExport.ink2)
                }
                Text("Sky Grid")
                    .font(SGFont.fixedDisplay(46, weight: .bold))
                    .foregroundStyle(SGExport.ink)
                Text("on the App Store")
                    .font(SGFont.fixedCaption(24))
                    .foregroundStyle(SGExport.ink2)
            }
        }
    }
}

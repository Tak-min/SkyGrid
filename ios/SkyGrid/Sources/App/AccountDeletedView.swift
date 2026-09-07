import SwiftUI

/// Shown once account deletion completes. Reuses the same quiet, ritual-mark
/// visual language as onboarding/plan screens instead of a generic system
/// `ContentUnavailableView`, so the very last screen someone sees still looks
/// like Sky Grid rather than an unstyled system error state.
struct AccountDeletedView: View {
    let onStartFresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.xl) {
            Spacer()

            RitualGridMark(side: 108)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: SGSpacing.sm) {
                Text("Your sky\nhas been cleared.")
                    .font(SGFont.title(36))
                    .foregroundStyle(SGT.ink)
                    .multilineTextAlignment(.leading)
                Text("Your photos, Sky Grid, and buddy connections have been removed from this device and the service.")
                    .font(SGFont.body(16))
                    .foregroundStyle(SGT.ink2)
            }

            Spacer()

            Button("Start fresh", action: onStartFresh)
                .frame(maxWidth: .infinity)
                .buttonStyle(SkyPrimaryButtonStyle())
        }
        .padding(SGSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGT.background)
    }
}

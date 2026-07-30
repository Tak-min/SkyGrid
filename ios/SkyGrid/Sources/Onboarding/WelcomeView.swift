import SwiftUI

struct WelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.xl) {
            OnboardingProgress(step: 1, total: 4)

            Spacer(minLength: 24)
            RitualGridMark()
                .frame(maxWidth: .infinity)
            Spacer(minLength: 16)

            Text("Keep one\nmorning sky.")
                .font(SGFont.serifTitle(42))
                .foregroundStyle(SGT.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Its color becomes one quiet day in your grid.")
                .font(SGFont.body(16))
                .foregroundStyle(SGT.ink2)

            Button(action: onNext) {
                Text("Get started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SkyPrimaryButtonStyle())
        }
        .padding(SGSpacing.xl)
    }
}

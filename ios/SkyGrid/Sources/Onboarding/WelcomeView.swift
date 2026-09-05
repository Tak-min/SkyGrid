import SwiftUI

struct WelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.xl) {
            OnboardingProgress(step: 1, total: 9)

            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                RitualGridMark()
                    .frame(maxWidth: .infinity)

                Text("Keep one\nmorning sky.")
                    .font(SGFont.serifTitle(42))
                    .foregroundStyle(SGT.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("It becomes one quiet day in your grid.")
                    .font(SGFont.body(16))
                    .foregroundStyle(SGT.ink2)

                Button(action: onNext) {
                    Text("Get started")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SkyPrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(SGSpacing.xl)
    }
}

import SwiftUI

struct WelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.xl) {
            OnboardingProgress(step: 1, total: 9)

            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                ZStack {
                    RitualGridMark()
                    MokuView(state: .ready, side: 118)
                        .offset(y: 24)
                }
                .frame(maxWidth: .infinity)

                Text("Keep one\nmorning sky.")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(SGT.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Moku turns each real morning into one bright tile in your grid.")
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
        .background(PlayfulStageBackdrop())
    }
}

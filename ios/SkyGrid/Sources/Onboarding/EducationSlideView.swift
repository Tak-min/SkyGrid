import SwiftUI

/// A short, focused explanation placed between onboarding questions.
struct EducationSlideView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    let headline: String
    let bodyCopy: String
    let symbolName: String
    let progressStep: Int
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                HStack {
                    onboardingBackButton(action: onBack)
                    Spacer()
                }
                .font(SGFont.caption(14))
                .foregroundStyle(SGT.ink2)

                OnboardingProgress(step: progressStep, total: OnboardingStep.allCases.count)

                Spacer(minLength: SGSpacing.lg)

                iconMark

                VStack(alignment: .leading, spacing: SGSpacing.md) {
                    Text(headline)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(SGT.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(bodyCopy)
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: SGSpacing.xl)
            }
            .padding(SGSpacing.xl)
            .padding(.bottom, SGSpacing.md)
            .opacity(appeared ? 1 : 0)
            .offset(y: reduceMotion || appeared ? 0 : SGSpacing.md)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            onboardingContinueButton(action: onContinue)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.52, dampingFraction: 0.84)) {
                appeared = true
            }
        }
    }

    private var iconMark: some View {
        Image(systemName: symbolName)
            .font(.system(size: 52, weight: .semibold))
            .foregroundStyle(SGT.accentInk)
            .frame(width: 120, height: 120)
            .background(
                LinearGradient(
                    colors: [SGT.accent, SGT.accentSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .shadow(color: SGT.ink.opacity(0.16), radius: 12, y: 6)
            .accessibilityHidden(true)
    }
}

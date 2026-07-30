import SwiftUI

/// One optional preference gives the plan a useful direction without turning the
/// first launch into a profile form. It stays on the device and is never used for
/// targeting or sent to a purchase provider.
struct PersonalizationQuestionsView: View {
    @Binding var profile: PersonalizationProfile
    let onNext: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                OnboardingProgress(step: 2, total: 4)

                VStack(alignment: .leading, spacing: SGSpacing.sm) {
                    Text("What would make\nmornings easier?")
                        .font(SGFont.serifTitle(38))
                        .foregroundStyle(SGT.ink)
                    Text("Choose one direction, or keep the quiet default. This stays on your device.")
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink2)
                }

                choiceSection("CHOOSE ONE") {
                    ForEach(MorningIntent.allCases) { intent in
                        ChoiceRow(
                            title: intent.title,
                            detail: intent.detail,
                            isSelected: profile.intent == intent
                        ) {
                            profile.intent = intent
                        }
                    }
                }

                Spacer(minLength: SGSpacing.sm)

                Button("Continue", action: onNext)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(SkyPrimaryButtonStyle())

                Button("Use the quiet default") {
                    profile = PersonalizationProfile()
                    onNext()
                }
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
            }
            .padding(SGSpacing.xl)
            .padding(.bottom, 32)
        }
    }

    private func choiceSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            Text(title)
                .font(SGFont.caption(11))
                .tracking(1.3)
                .foregroundStyle(SGT.ink3)
            VStack(spacing: 8, content: content)
        }
    }
}

private struct ChoiceRow: View {
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: SGSpacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(isSelected ? SGT.ink : SGT.ink3)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink)
                    Text(detail)
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(SGSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? SGT.fill : SGT.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? SGT.ink.opacity(0.38) : SGT.rule, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

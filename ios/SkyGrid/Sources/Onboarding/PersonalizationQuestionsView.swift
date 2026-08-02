import SwiftUI

/// One optional preference gives the plan a useful direction without turning the
/// first launch into a profile form. It stays on the device and is never used for
/// targeting or sent to a purchase provider.
struct PersonalizationQuestionsView: View {
    @Binding var profile: PersonalizationProfile
    let onBack: () -> Void
    let onSkip: () -> Void
    let onNext: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                onboardingNavigation
                OnboardingProgress(step: 2, total: 8)

                VStack(alignment: .leading, spacing: SGSpacing.sm) {
                    Text("What would make\nmornings easier?")
                        .font(SGFont.serifTitle(38))
                        .foregroundStyle(SGT.ink)
                    Text("QUESTION 1 OF 6 · Choose a direction. This stays on your device.")
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
            }
            .padding(SGSpacing.xl)
            .padding(.bottom, 32)
        }
    }

    private var onboardingNavigation: some View {
        HStack {
            Button("Back", action: onBack)
            Spacer()
            Button("Skip setup", action: onSkip)
        }
        .font(SGFont.caption(14))
        .foregroundStyle(SGT.ink2)
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

/// A shared single-question page layout: navigation row, progress bar, heading,
/// one choice list, and a Continue button. `RitualRhythmQuestionsView` and
/// `PrivacyAndReminderQuestionsView` used to each pack two of these onto one
/// screen — split into `PaceQuestionView`/`FrequencyQuestionView` and
/// `PrivacyQuestionView`/`ReminderQuestionView` below so every question gets
/// its own page, matching `PersonalizationQuestionsView`'s existing shape.
private struct SingleQuestionPage<Content: View>: View {
    let step: Int
    let heading: String
    let subheading: String
    let onBack: () -> Void
    let onSkip: () -> Void
    let onNext: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                navigation
                OnboardingProgress(step: step, total: 8)

                VStack(alignment: .leading, spacing: SGSpacing.sm) {
                    Text(heading)
                        .font(SGFont.serifTitle(38))
                        .foregroundStyle(SGT.ink)
                    Text(subheading)
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink2)
                }

                VStack(spacing: 8, content: { content })

                Button("Continue", action: onNext)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(SkyPrimaryButtonStyle())
            }
            .padding(SGSpacing.xl)
            .padding(.bottom, 32)
        }
    }

    private var navigation: some View {
        HStack {
            Button("Back", action: onBack)
            Spacer()
            Button("Skip setup", action: onSkip)
        }
        .font(SGFont.caption(14))
        .foregroundStyle(SGT.ink2)
    }
}

struct PaceQuestionView: View {
    @Binding var profile: PersonalizationProfile
    let onBack: () -> Void
    let onSkip: () -> Void
    let onNext: () -> Void

    var body: some View {
        SingleQuestionPage(
            step: 3,
            heading: "Make the ritual\nyour own.",
            subheading: "QUESTION 2 OF 6 · How should it feel? You can change this later.",
            onBack: onBack,
            onSkip: onSkip,
            onNext: onNext
        ) {
            ForEach(RitualPace.allCases) { pace in
                ChoiceRow(title: pace.title, detail: pace.detail, isSelected: profile.pace == pace) {
                    profile.pace = pace
                }
            }
        }
    }
}

struct FrequencyQuestionView: View {
    @Binding var profile: PersonalizationProfile
    let onBack: () -> Void
    let onSkip: () -> Void
    let onNext: () -> Void

    var body: some View {
        SingleQuestionPage(
            step: 4,
            heading: "How often\nfeels right?",
            subheading: "QUESTION 3 OF 6 · You can change this later.",
            onBack: onBack,
            onSkip: onSkip,
            onNext: onNext
        ) {
            ForEach(RitualFrequency.allCases) { frequency in
                ChoiceRow(title: frequency.title, detail: frequency.detail, isSelected: profile.frequency == frequency) {
                    profile.frequency = frequency
                }
            }
        }
    }
}

struct PrivacyQuestionView: View {
    @Binding var profile: PersonalizationProfile
    let onBack: () -> Void
    let onSkip: () -> Void
    let onNext: () -> Void

    var body: some View {
        SingleQuestionPage(
            step: 5,
            heading: "Keep it private,\nor make room to share.",
            subheading: "QUESTION 4 OF 6 · Who is this for? Nothing is sent from this answer.",
            onBack: onBack,
            onSkip: onSkip,
            onNext: onNext
        ) {
            ForEach(RitualPrivacy.allCases) { privacy in
                ChoiceRow(title: privacy.title, detail: privacy.detail, isSelected: profile.privacy == privacy) {
                    profile.privacy = privacy
                }
            }
        }
    }
}

struct ReminderQuestionView: View {
    @Binding var profile: PersonalizationProfile
    let onBack: () -> Void
    let onSkip: () -> Void
    let onNext: () -> Void

    var body: some View {
        SingleQuestionPage(
            step: 6,
            heading: "What should\nbring you back?",
            subheading: "QUESTION 5 OF 6 · Nothing is sent from this answer.",
            onBack: onBack,
            onSkip: onSkip,
            onNext: onNext
        ) {
            ForEach(ReminderPreference.allCases) { reminder in
                ChoiceRow(title: reminder.title, detail: reminder.detail, isSelected: profile.reminder == reminder) {
                    profile.reminder = reminder
                }
            }
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
                    .contentTransition(.symbolEffect(.replace))
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
            .skyAnimation(SGMotion.settle, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

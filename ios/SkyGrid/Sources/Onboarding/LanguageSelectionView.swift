import SwiftUI

struct LanguageSelectionView: View {
    @Environment(LocalizationController.self) private var localization
    let onNext: () -> Void
    @State private var selection: AppLanguage?

    init(onNext: @escaping () -> Void) {
        self.onNext = onNext
        _selection = State(initialValue: LocalDefaults.selectedLanguageCode.flatMap(AppLanguage.init(rawValue:)) ?? AppLanguage.onboardingInitialSelection())
    }

    var body: some View {
        VStack(spacing: SGSpacing.xl) {
            OnboardingProgress(step: 1, total: 10)
            Spacer(minLength: SGSpacing.lg)
            MokuView(state: .ready, side: 132)
                .accessibilityHidden(true)

            VStack(spacing: SGSpacing.sm) {
                Text(L10n.string(selection == nil ? "language.choose.title" : "language.confirm.title", language: localization.language))
                    .font(SGFont.display(30))
                    .multilineTextAlignment(.center)
                Text(L10n.string(selection == nil ? "language.choose.detail" : "language.confirm.detail", language: localization.language))
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: SGSpacing.sm) {
                languageButton(.english)
                languageButton(.japanese)
            }

            Spacer()

            Button(L10n.string("language.continue", language: localization.language)) {
                guard let selection else { return }
                localization.select(selection)
                onNext()
            }
            .buttonStyle(SkyPrimaryButtonStyle())
            .disabled(selection == nil)
            .accessibilityIdentifier("onboarding.language.continue")
        }
        .padding(SGSpacing.xl)
        .background(PlayfulStageBackdrop())
    }

    private func languageButton(_ language: AppLanguage) -> some View {
        Button {
            selection = language
            localization.select(language)
        } label: {
            HStack {
                Text(language.displayName)
                    .font(SGFont.body(17))
                Spacer()
                if selection == language {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .padding(.horizontal, SGSpacing.lg)
            .frame(minHeight: 56)
            .background(SGT.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == language ? .isSelected : [])
    }
}

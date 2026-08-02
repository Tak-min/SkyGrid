import Observation
import SwiftUI

enum OnboardingStep: Equatable {
    case welcome
    case intention
    case pace
    case frequency
    case privacy
    case reminder
    case wakeGoal
    case plan
}

@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var step: OnboardingStep = .welcome
    var wakeGoalMinutes: Int = LocalDefaults.wakeGoalMinutes
    var personalizationProfile = LocalDefaults.personalizationProfile
    private(set) var didComplete = false

    func advanceToIntention() {
        step = .intention
    }

    func advanceToPace() {
        step = .pace
    }

    func advanceToFrequency() {
        step = .frequency
    }

    func advanceToPrivacy() {
        step = .privacy
    }

    func advanceToReminder() {
        step = .reminder
    }

    func advanceToWakeGoal() {
        step = .wakeGoal
    }

    func advanceToPlan() {
        step = .plan
    }

    func goBack(to step: OnboardingStep) {
        self.step = step
    }

    func skipToPlan() {
        personalizationProfile = PersonalizationProfile()
        wakeGoalMinutes = LocalDefaults.wakeGoalMinutes
        step = .plan
    }

    func complete() {
        guard !didComplete else { return }
        didComplete = true
        LocalDefaults.wakeGoalMinutes = wakeGoalMinutes
        LocalDefaults.personalizationProfile = personalizationProfile
        LocalDefaults.onboardingDone = true
    }
}

/// A short, preference-led setup. Permissions are requested only at the moment a
/// person explicitly enables an alarm or opens the camera; neither is a condition
/// for reaching their first morning.
struct OnboardingCoordinatorView: View {
    @State private var viewModel = OnboardingViewModel()
    @State private var showPaywall = false
    let purchases: any PurchasesServicing
    let entitlements: EntitlementStore
    let onFinished: () -> Void

    var body: some View {
        Group {
            switch viewModel.step {
            case .welcome:
                WelcomeView { viewModel.advanceToIntention() }
            case .intention:
                PersonalizationQuestionsView(
                    profile: $viewModel.personalizationProfile,
                    onBack: { viewModel.goBack(to: .welcome) },
                    onSkip: viewModel.skipToPlan
                ) {
                    viewModel.advanceToPace()
                }
            case .pace:
                PaceQuestionView(
                    profile: $viewModel.personalizationProfile,
                    onBack: { viewModel.goBack(to: .intention) },
                    onSkip: viewModel.skipToPlan
                ) {
                    viewModel.advanceToFrequency()
                }
            case .frequency:
                FrequencyQuestionView(
                    profile: $viewModel.personalizationProfile,
                    onBack: { viewModel.goBack(to: .pace) },
                    onSkip: viewModel.skipToPlan
                ) {
                    viewModel.advanceToPrivacy()
                }
            case .privacy:
                PrivacyQuestionView(
                    profile: $viewModel.personalizationProfile,
                    onBack: { viewModel.goBack(to: .frequency) },
                    onSkip: viewModel.skipToPlan
                ) {
                    viewModel.advanceToReminder()
                }
            case .reminder:
                ReminderQuestionView(
                    profile: $viewModel.personalizationProfile,
                    onBack: { viewModel.goBack(to: .privacy) },
                    onSkip: viewModel.skipToPlan
                ) {
                    viewModel.advanceToWakeGoal()
                }
            case .wakeGoal:
                WakeGoalPickerView(
                    minutes: $viewModel.wakeGoalMinutes,
                    reminderPreference: viewModel.personalizationProfile.reminder ?? .gentleReminder,
                    onBack: { viewModel.goBack(to: .reminder) }
                ) {
                    viewModel.advanceToPlan()
                }
            case .plan:
                PersonalizedPlanView(
                    profile: viewModel.personalizationProfile,
                    wakeGoalMinutes: viewModel.wakeGoalMinutes,
                    onExplorePro: { showPaywall = true },
                    onContinueFree: finish,
                    onEditAnswers: { viewModel.goBack(to: .wakeGoal) }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGT.background)
        .animation(.easeInOut(duration: 0.24), value: viewModel.step)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(
                purchases: purchases,
                entryPoint: .onboarding(
                    profile: viewModel.personalizationProfile,
                    wakeGoalMinutes: viewModel.wakeGoalMinutes
                ),
                onEntitlementGranted: {
                    await entitlements.refresh()
                    finish()
                },
                onDismissed: { _ in finish() }
            )
        }
    }

    private func finish() {
        guard !viewModel.didComplete else { return }
        viewModel.complete()
        showPaywall = false
        onFinished()
    }
}

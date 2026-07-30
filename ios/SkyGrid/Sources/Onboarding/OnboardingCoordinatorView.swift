import Observation
import SwiftUI

enum OnboardingStep: Int {
    case welcome, questions, wakeGoal, personalizedPlan
}

@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var step: OnboardingStep = .welcome
    var wakeGoalMinutes: Int = LocalDefaults.wakeGoalMinutes
    var personalizationProfile = LocalDefaults.personalizationProfile
    private(set) var didComplete = false

    func advance(onFinished: () -> Void) {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else {
            complete()
            onFinished()
            return
        }
        step = next
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
                WelcomeView { viewModel.advance(onFinished: onFinished) }
            case .questions:
                PersonalizationQuestionsView(profile: $viewModel.personalizationProfile) {
                    viewModel.advance(onFinished: onFinished)
                }
            case .wakeGoal:
                WakeGoalPickerView(minutes: $viewModel.wakeGoalMinutes) {
                    viewModel.advance(onFinished: onFinished)
                }
            case .personalizedPlan:
                PersonalizedPlanView(
                    profile: viewModel.personalizationProfile,
                    wakeGoalMinutes: viewModel.wakeGoalMinutes,
                    onExplorePro: { showPaywall = true },
                    onContinueFree: finish
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
                    Task { await entitlements.refresh() }
                    finish()
                },
                onContinueWithFree: finish
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

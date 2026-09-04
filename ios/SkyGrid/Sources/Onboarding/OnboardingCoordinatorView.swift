import Observation
import SwiftUI

enum OnboardingStep: String, Equatable {
    case welcome
    case intention
    case pace
    case frequency
    case privacy
    case reminder
    case wakeGoal
    case plan
    case invite
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

    func advanceToInvite() {
        step = .invite
    }

    func goBack(to step: OnboardingStep) {
        self.step = step
    }

    func advance() {
        switch step {
        case .welcome: step = .intention
        case .intention: step = .pace
        case .pace: step = .frequency
        case .frequency: step = .privacy
        case .privacy: step = .reminder
        case .reminder: step = .wakeGoal
        case .wakeGoal: step = .plan
        case .plan: step = .invite
        case .invite: break
        }
    }

    func goBackOneStep() {
        switch step {
        case .welcome: break
        case .intention: step = .welcome
        case .pace: step = .intention
        case .frequency: step = .pace
        case .privacy: step = .frequency
        case .reminder: step = .privacy
        case .wakeGoal: step = .reminder
        case .plan: step = .wakeGoal
        case .invite: step = .plan
        }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = OnboardingViewModel()
    @State private var showPaywall = false
    @State private var transitionEdge: Edge = .trailing
    let purchases: any PurchasesServicing
    let entitlements: EntitlementStore
    let uid: String
    let userRepository: any UserRepository
    let inviteRepository: any InviteRepository
    let onFinished: () -> Void

    var body: some View {
        Group {
            switch viewModel.step {
            case .welcome:
                WelcomeView(onNext: advance)
            case .intention:
                PersonalizationQuestionsView(
                    profile: $viewModel.personalizationProfile,
                    onBack: goBack,
                    onSkip: skipToPlan
                ) {
                    advance()
                }
            case .pace:
                PaceQuestionView(
                    profile: $viewModel.personalizationProfile,
                    onBack: goBack,
                    onSkip: skipToPlan
                ) {
                    advance()
                }
            case .frequency:
                FrequencyQuestionView(
                    profile: $viewModel.personalizationProfile,
                    onBack: goBack,
                    onSkip: skipToPlan
                ) {
                    advance()
                }
            case .privacy:
                PrivacyQuestionView(
                    profile: $viewModel.personalizationProfile,
                    onBack: goBack,
                    onSkip: skipToPlan
                ) {
                    advance()
                }
            case .reminder:
                ReminderQuestionView(
                    profile: $viewModel.personalizationProfile,
                    onBack: goBack,
                    onSkip: skipToPlan
                ) {
                    advance()
                }
            case .wakeGoal:
                WakeGoalPickerView(
                    minutes: $viewModel.wakeGoalMinutes,
                    reminderPreference: viewModel.personalizationProfile.reminder ?? .gentleReminder,
                    onBack: goBack
                ) {
                    advance()
                }
            case .plan:
                PersonalizedPlanView(
                    profile: viewModel.personalizationProfile,
                    wakeGoalMinutes: viewModel.wakeGoalMinutes,
                    onExplorePro: { showPaywall = true },
                    onContinueFree: advanceToInvite,
                    onEditAnswers: goBack
                )
            case .invite:
                OnboardingInviteView(
                    uid: uid,
                    userRepository: userRepository,
                    inviteRepository: inviteRepository,
                    onSkip: finish
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGT.background)
        .id(viewModel.step)
        // A task keyed by the current step runs once for the initial screen and
        // once for each actual new step. Pairing `onAppear` with `onChange` here
        // would double-count because `.id(viewModel.step)` recreates the subtree.
        .task(id: viewModel.step) {
            OnboardingAnalytics.record(.stepViewed, step: viewModel.step)
        }
        .transition(reduceMotion ? .identity : .asymmetric(
            insertion: .move(edge: transitionEdge).combined(with: .opacity),
            removal: .move(edge: transitionEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
        ))
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height),
                          abs(value.translation.width) > 56
                    else { return }
                    if value.translation.width < 0 {
                        advance()
                    } else {
                        goBack()
                    }
                }
        )
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(
                purchases: purchases,
                entryPoint: .onboarding(
                    profile: viewModel.personalizationProfile,
                    wakeGoalMinutes: viewModel.wakeGoalMinutes
                ),
                onEntitlementGranted: {
                    await entitlements.refresh()
                    advanceToInvite()
                },
                onDismissed: { _ in advanceToInvite() }
            )
        }
    }

    private func finish() {
        guard !viewModel.didComplete else { return }
        OnboardingAnalytics.record(.completed, step: viewModel.step)
        viewModel.complete()
        showPaywall = false
        onFinished()
    }

    private func advance() {
        guard viewModel.step != .invite else { return }
        OnboardingAnalytics.record(.stepAdvanced, step: viewModel.step)
        transitionEdge = .trailing
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            viewModel.advance()
        }
    }

    private func goBack() {
        guard viewModel.step != .welcome else { return }
        OnboardingAnalytics.record(.stepBacked, step: viewModel.step)
        transitionEdge = .leading
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            viewModel.goBackOneStep()
        }
    }

    private func skipToPlan() {
        OnboardingAnalytics.record(.stepSkipped, step: viewModel.step)
        transitionEdge = .trailing
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            viewModel.skipToPlan()
        }
    }

    private func advanceToInvite() {
        guard viewModel.step != .invite else { return }
        OnboardingAnalytics.record(.stepAdvanced, step: viewModel.step)
        transitionEdge = .trailing
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            viewModel.advanceToInvite()
        }
    }
}

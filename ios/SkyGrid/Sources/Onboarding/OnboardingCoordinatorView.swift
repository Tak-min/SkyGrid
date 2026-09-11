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

    func completeForFirstCapture() {
        LocalDefaults.openCameraAfterOnboarding = true
        LocalDefaults.pendingOnboardingPaywallAfterFirstCapture = true
        complete()
    }
}

/// A short, preference-led setup. Permissions are requested only at the moment a
/// person explicitly enables an alarm or opens the camera; neither is a condition
/// for reaching their first morning.
struct OnboardingCoordinatorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = OnboardingViewModel()
    @State private var showPaywall = false
    @State private var companionInteraction = 0
    let purchases: any PurchasesServicing
    let entitlements: EntitlementStore
    let uid: String
    let userRepository: any UserRepository
    let inviteRepository: any InviteRepository
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.step != .welcome {
                companionRail
            }
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
                    onStartFirstSky: finishForFirstCapture,
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
            .id(viewModel.step)
            .transition(.opacity)
        }
        .background(PlayfulStageBackdrop())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGT.background)
        // The companion and modal owner retain their identities as page content
        // changes. Only the page is replaced, so transitions cannot duplicate Moku.
        .task(id: viewModel.step) {
            OnboardingAnalytics.record(.stepViewed, step: viewModel.step)
        }
        .onChange(of: viewModel.personalizationProfile) { _, _ in
            Haptics.selectionChanged()
            companionInteraction += 1
        }
        .onChange(of: viewModel.step) { oldStep, newStep in
            if oldStep != .welcome && newStep != .welcome {
                companionInteraction += 1
            }
        }
        // Horizontal page gestures are scoped to the companion rail. The previous
        // page-wide gesture also received drags originating in choices and wheels.
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

    private var companionRail: some View {
        HStack(spacing: SGSpacing.md) {
            MokuView(state: .ready, side: 52, interaction: companionInteraction, interactionFeedback: false)
                .frame(width: 66, height: 64)
            Text(companionLine)
                .font(SGFont.caption(13))
                .foregroundStyle(SGT.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SGSpacing.xl)
        .padding(.top, SGSpacing.sm)
        .padding(.bottom, SGSpacing.xs)
        .background(SGT.accentSecondary.opacity(0.055))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height),
                          abs(value.translation.width) > 56 else { return }
                    navigateFromRail(forward: value.translation.width < 0)
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Setup page")
        // The visible companion line, not `step.rawValue`: that is an analytics key
        // (`wake_goal`) and VoiceOver read it aloud verbatim.
        .accessibilityValue(companionLine)
        // Announced as adjustable only where adjusting actually moves. The alarm,
        // plan and invite steps keep their explicit buttons, so advertising an
        // increment there promised a control that silently did nothing.
        .modifier(RailAdjustableAction(isEnabled: isRailNavigable, navigate: navigateFromRail))
        .accessibilityIdentifier("onboarding.companionRail")
    }

    /// The preference questions are optional. Alarm scheduling and plan/free
    /// decisions retain their explicit buttons, including their busy guards.
    private var isRailNavigable: Bool {
        [.intention, .pace, .frequency, .privacy, .reminder].contains(viewModel.step)
    }

    private func navigateFromRail(forward: Bool) {
        guard isRailNavigable else { return }
        if forward { advance() } else { goBack() }
    }

    private var companionLine: String {
        switch viewModel.step {
        case .welcome: "One sky is a beginning."
        case .intention:
            viewModel.personalizationProfile.intent.map { "\($0.title) — a good place to begin." }
                ?? "Let's make this morning yours."
        case .pace:
            viewModel.personalizationProfile.pace.map { "\($0.title) works. I'll follow your pace." }
                ?? "A pace that feels like you."
        case .frequency:
            viewModel.personalizationProfile.frequency.map { "\($0.title). There's room for real life." }
                ?? "There's room for real life."
        case .privacy:
            viewModel.personalizationProfile.privacy.map { "\($0.title). Your sky stays yours." }
                ?? "Your sky. Your circle."
        case .reminder:
            viewModel.personalizationProfile.reminder.map { "\($0.title). You stay in control." }
                ?? "You choose the nudge."
        case .wakeGoal: "A time to look up."
        case .plan: "Your first sky is next."
        case .invite: "Together is optional. Your sky is yours."
        }
    }

    private func finish() {
        guard !viewModel.didComplete else { return }
        Haptics.navigationConfirmed()
        SoundEffectPlayer.shared.play(.forwardNavigation)
        OnboardingAnalytics.record(.completed, step: viewModel.step)
        viewModel.complete()
        showPaywall = false
        onFinished()
    }

    private func finishForFirstCapture() {
        guard !viewModel.didComplete else { return }
        Haptics.navigationConfirmed()
        SoundEffectPlayer.shared.play(.forwardNavigation)
        OnboardingAnalytics.record(.completed, step: viewModel.step)
        viewModel.completeForFirstCapture()
        showPaywall = false
        onFinished()
    }

    private func advance() {
        guard viewModel.step != .invite else { return }
        Haptics.navigationConfirmed()
        SoundEffectPlayer.shared.play(.forwardNavigation)
        OnboardingAnalytics.record(.stepAdvanced, step: viewModel.step)
        withAnimation(viewModel.step == .welcome ? nil : pageAnimation) {
            viewModel.advance()
        }
    }

    private func goBack() {
        guard viewModel.step != .welcome else { return }
        Haptics.navigationConfirmed()
        // Backward navigation intentionally stays haptic-only; the swish marks forward progress.
        OnboardingAnalytics.record(.stepBacked, step: viewModel.step)
        withAnimation(viewModel.step == .intention ? nil : pageAnimation) {
            viewModel.goBackOneStep()
        }
    }

    private func skipToPlan() {
        Haptics.navigationConfirmed()
        SoundEffectPlayer.shared.play(.forwardNavigation)
        OnboardingAnalytics.record(.stepSkipped, step: viewModel.step)
        withAnimation(pageAnimation) {
            viewModel.skipToPlan()
        }
    }

    private func advanceToInvite() {
        guard viewModel.step != .invite else { return }
        Haptics.navigationConfirmed()
        SoundEffectPlayer.shared.play(.forwardNavigation)
        OnboardingAnalytics.record(.stepAdvanced, step: viewModel.step)
        withAnimation(pageAnimation) {
            viewModel.advanceToInvite()
        }
    }

    private var pageAnimation: Animation? {
        reduceMotion || !MokuMotionPolicy.animationsEnabled ? nil : .easeOut(duration: 0.18)
    }
}

/// Attaches the adjustable action only when it can do something. A conditional
/// modifier rather than a no-op closure: VoiceOver announces the trait itself.
private struct RailAdjustableAction: ViewModifier {
    let isEnabled: Bool
    let navigate: (Bool) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: navigate(true)
                case .decrement: navigate(false)
                @unknown default: break
                }
            }
        } else {
            content
        }
    }
}

import Observation
import SwiftUI

enum OnboardingStep: String, Equatable, CaseIterable {
    case language
    case welcome
    case intention
    case educationCircadian
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
    private(set) var step: OnboardingStep
    var wakeGoalMinutes: Int = LocalDefaults.wakeGoalMinutes
    var personalizationProfile = LocalDefaults.personalizationProfile
    private(set) var didComplete = false

    init(step: OnboardingStep = .welcome) {
        self.step = step
    }

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
        case .language: step = .welcome
        case .welcome: step = .intention
        case .intention: step = .educationCircadian
        case .educationCircadian: step = .pace
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
        case .language: break
        case .welcome: step = .language
        case .intention: step = .welcome
        case .educationCircadian: step = .intention
        case .pace: step = .educationCircadian
        case .frequency: step = .pace
        case .privacy: step = .frequency
        case .reminder: step = .privacy
        case .wakeGoal: step = .reminder
        case .plan: step = .wakeGoal
        case .invite: step = .plan
        }
    }

    func complete() {
        guard !didComplete else { return }
        didComplete = true
        LocalDefaults.wakeGoalMinutes = wakeGoalMinutes
        LocalDefaults.personalizationProfile = personalizationProfile
        LocalDefaults.onboardingInvitePosture = OnboardingInvitePosture(privacy: personalizationProfile.privacy)
        seedMorningAlarmDefaultIfNeeded()
        LocalDefaults.onboardingDone = true
    }

    func completeForFirstCapture() {
        LocalDefaults.openCameraAfterOnboarding = true
        LocalDefaults.pendingOnboardingPaywallAfterFirstCapture = true
        complete()
    }

    private func seedMorningAlarmDefaultIfNeeded() {
        guard LocalDefaults.morningAlarmSchedules.isEmpty else { return }

        let enabled = personalizationProfile.reminder == .scheduledAlarm
        LocalDefaults.morningAlarmEnabled = enabled
        LocalDefaults.morningAlarmSchedules = MorningAlarmSchedule.onboardingDefault(
            enabled: enabled,
            wakeGoalMinutes: wakeGoalMinutes,
            pace: personalizationProfile.pace
        )
        // The migration path has already run conceptually. Marking it complete
        // keeps it from replacing the pace-specific weekdays with its old all-days default.
        LocalDefaults.morningAlarmScheduleModelVersion = 1
    }
}

/// A short, preference-led setup. Permissions are requested only at the moment a
/// person explicitly enables an alarm or opens the camera; neither is a condition
/// for reaching their first morning.
struct OnboardingCoordinatorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = OnboardingViewModel(step: .language)
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
            if viewModel.step != .language && viewModel.step != .welcome {
                companionRail
            }
            Group {
            switch viewModel.step {
            case .language:
                LanguageSelectionView(onNext: advance)
            case .welcome:
                WelcomeView(onNext: advance)
            case .intention:
                PersonalizationQuestionsView(
                    profile: $viewModel.personalizationProfile,
                    onBack: goBack
                ) {
                    advance()
                }
            case .educationCircadian:
                EducationSlideView(
                    headline: L10n.string("onboarding.education.circadian.headline"),
                    bodyCopy: L10n.string("onboarding.education.circadian.body"),
                    symbolName: "sun.horizon.fill",
                    progressStep: 4,
                    onBack: goBack,
                    onContinue: advance
                )
            case .pace:
                PaceQuestionView(
                    profile: $viewModel.personalizationProfile,
                    onBack: goBack
                ) {
                    advance()
                }
            case .frequency:
                FrequencyQuestionView(
                    profile: $viewModel.personalizationProfile,
                    onBack: goBack
                ) {
                    advance()
                }
            case .privacy:
                PrivacyQuestionView(
                    profile: $viewModel.personalizationProfile,
                    onBack: goBack
                ) {
                    advance()
                }
            case .reminder:
                ReminderQuestionView(
                    profile: $viewModel.personalizationProfile,
                    onBack: goBack
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
                    onStartFirstSky: advanceToInvite,
                    onEditAnswers: goBack
                )
            case .invite:
                OnboardingInviteView(
                    uid: uid,
                    userRepository: userRepository,
                    inviteRepository: inviteRepository,
                    onBack: goBack,
                    onContinue: finishForFirstCapture
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.string("onboarding.coordinator.accessibilityLabel"))
        // The visible companion line, not `step.rawValue`: that is an analytics key
        // (`wake_goal`) and VoiceOver read it aloud verbatim.
        .accessibilityValue(companionLine)
        .accessibilityIdentifier("onboarding.companionRail")
    }

    // Routed through `L10n.string(_:)`: `Text(companionLine)` / `.accessibilityValue`
    // consume this as a stored `String` property, not a `Text("literal")` call site,
    // so automatic String Catalog key matching does not apply (see
    // `dev-notes/localization-en-ja-stage2_*.md`).
    private var companionLine: String {
        switch viewModel.step {
        case .language: L10n.string("onboarding.companion.language")
        case .welcome: L10n.string("onboarding.companion.welcome")
        case .intention:
            viewModel.personalizationProfile.intent.map {
                String(format: L10n.string("onboarding.companion.intention.answered"), $0.title)
            } ?? L10n.string("onboarding.companion.intention.unanswered")
        case .educationCircadian: L10n.string("onboarding.companion.educationCircadian")
        case .pace:
            viewModel.personalizationProfile.pace.map {
                String(format: L10n.string("onboarding.companion.pace.answered"), $0.title)
            } ?? L10n.string("onboarding.companion.pace.unanswered")
        case .frequency:
            viewModel.personalizationProfile.frequency.map {
                String(format: L10n.string("onboarding.companion.frequency.answered"), $0.title)
            } ?? L10n.string("onboarding.companion.frequency.unanswered")
        case .privacy:
            viewModel.personalizationProfile.privacy.map {
                String(format: L10n.string("onboarding.companion.privacy.answered"), $0.title)
            } ?? L10n.string("onboarding.companion.privacy.unanswered")
        case .reminder:
            viewModel.personalizationProfile.reminder.map {
                String(format: L10n.string("onboarding.companion.reminder.answered"), $0.title)
            } ?? L10n.string("onboarding.companion.reminder.unanswered")
        case .wakeGoal: L10n.string("onboarding.companion.wakeGoal")
        case .plan: L10n.string("onboarding.companion.plan")
        case .invite: L10n.string("onboarding.companion.invite")
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
        withAnimation(viewModel.step == .language || viewModel.step == .welcome ? nil : pageAnimation) {
            viewModel.advance()
        }
    }

    private func goBack() {
        guard viewModel.step != .language else { return }
        Haptics.navigationConfirmed()
        // Backward navigation intentionally stays haptic-only; the swish marks forward progress.
        OnboardingAnalytics.record(.stepBacked, step: viewModel.step)
        withAnimation(viewModel.step == .welcome || viewModel.step == .intention ? nil : pageAnimation) {
            viewModel.goBackOneStep()
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

import Foundation
import Testing
@testable import SkyGrid

@Suite("Onboarding personalization defaults")
@MainActor
struct OnboardingPersonalizationDefaultsTests {
    @Test("scheduled structured mornings seed an every-day alarm")
    func seedsStructuredAlarm() {
        withFreshAlarmDefaults {
            let viewModel = OnboardingViewModel()
            viewModel.wakeGoalMinutes = 6 * 60 + 45
            viewModel.personalizationProfile = PersonalizationProfile(pace: .structured, reminder: .scheduledAlarm)

            viewModel.complete()

            #expect(LocalDefaults.morningAlarmEnabled)
            #expect(LocalDefaults.morningAlarmSchedules.count == 1)
            #expect(LocalDefaults.morningAlarmSchedules.first?.minutesAfterMidnight == 405)
            #expect(LocalDefaults.morningAlarmSchedules.first?.weekdays == Set(1...7))
            #expect(LocalDefaults.morningAlarmScheduleModelVersion == 1)
        }
    }

    @Test("gentle and flexible paces create lighter scheduled defaults")
    func seedsLighterPaceDefaults() {
        #expect(MorningAlarmSchedule.onboardingDefault(enabled: true, wakeGoalMinutes: 360, pace: .gentle).first?.weekdays == Set(2...6))
        #expect(MorningAlarmSchedule.onboardingDefault(enabled: true, wakeGoalMinutes: 360, pace: .flexible).first?.weekdays == Set([2, 4, 6]))
        #expect(MorningAlarmSchedule.onboardingDefault(enabled: false, wakeGoalMinutes: 360, pace: .structured).isEmpty)
    }

    @Test("a non-alarm preference leaves the seeded alarm disabled")
    func doesNotSeedAlarmWithoutScheduledReminder() {
        withFreshAlarmDefaults {
            let viewModel = OnboardingViewModel()
            viewModel.personalizationProfile = PersonalizationProfile(pace: .structured, reminder: .gentleReminder)

            viewModel.complete()

            #expect(!LocalDefaults.morningAlarmEnabled)
            #expect(LocalDefaults.morningAlarmSchedules.isEmpty)
        }
    }

    @Test("existing alarm schedules are never overwritten at completion")
    func preservesCustomizedSchedules() {
        withFreshAlarmDefaults {
            let customized = MorningAlarmSchedule(
                id: UUID(), minutesAfterMidnight: 7 * 60 + 10, weekdays: [1, 7], isEnabled: true
            )
            LocalDefaults.morningAlarmSchedules = [customized]
            LocalDefaults.morningAlarmEnabled = true
            LocalDefaults.morningAlarmScheduleModelVersion = 1
            let viewModel = OnboardingViewModel()
            viewModel.personalizationProfile = PersonalizationProfile(pace: .structured, reminder: .scheduledAlarm)

            viewModel.complete()

            #expect(LocalDefaults.morningAlarmSchedules == [customized])
            #expect(LocalDefaults.morningAlarmEnabled)
        }
    }

    @Test("neutral invite copy remains the current copy for later or unanswered privacy")
    func keepsNeutralInviteCopy() {
        let currentCopy = L10n.string("Invite people you trust. Each sky stays sealed until you've each captured the same morning.")

        #expect(OnboardingInvitePosture(privacy: nil) == .neutral)
        #expect(OnboardingInvitePosture(privacy: .decideLater) == .neutral)
        #expect(OnboardingInvitePosture(privacy: nil).bodyCopy == currentCopy)
        #expect(OnboardingInvitePosture(privacy: .decideLater).bodyCopy == currentCopy)
        #expect(OnboardingInvitePosture(privacy: .privateRitual).bodyCopy == L10n.string("onboarding.invite.privateRitual.body"))
        #expect(OnboardingInvitePosture(privacy: .shareWithBuddy).bodyCopy == L10n.string("onboarding.invite.shareWithBuddy.body"))
    }

    private func withFreshAlarmDefaults(_ body: () -> Void) {
        let schedules = LocalDefaults.morningAlarmSchedules
        let enabled = LocalDefaults.morningAlarmEnabled
        let modelVersion = LocalDefaults.morningAlarmScheduleModelVersion
        let done = LocalDefaults.onboardingDone
        let profile = LocalDefaults.personalizationProfile
        let invitePosture = LocalDefaults.onboardingInvitePosture
        defer {
            LocalDefaults.morningAlarmSchedules = schedules
            LocalDefaults.morningAlarmEnabled = enabled
            LocalDefaults.morningAlarmScheduleModelVersion = modelVersion
            LocalDefaults.onboardingDone = done
            LocalDefaults.personalizationProfile = profile
            LocalDefaults.onboardingInvitePosture = invitePosture
        }
        LocalDefaults.morningAlarmSchedules = []
        LocalDefaults.morningAlarmEnabled = false
        LocalDefaults.morningAlarmScheduleModelVersion = 0
        LocalDefaults.onboardingDone = false
        body()
    }
}

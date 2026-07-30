import Foundation

enum PaywallEntryPoint {
    case onboarding(profile: PersonalizationProfile, wakeGoalMinutes: Int)
    case archive
    case settings

    var headline: String {
        switch self {
        case .onboarding(let profile, let wakeGoalMinutes):
            return PersonalizedMorningPlanBuilder.make(profile: profile, wakeGoalMinutes: wakeGoalMinutes).proLead
        case .archive:
            return "Keep every morning in one continuous Sky Grid."
        case .settings:
            return "Keep the long view of your mornings."
        }
    }

    var permitsExitOffer: Bool {
        if case .onboarding = self { return true }
        return false
    }
}

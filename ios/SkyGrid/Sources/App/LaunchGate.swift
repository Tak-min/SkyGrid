import Foundation

enum LaunchDestination: Equatable {
    case onboarding
    case today
}

/// Pure routing decision. A handle belongs to the optional buddy flow, not to the
/// first-morning ritual, so anonymous users reach Today as soon as onboarding ends.
enum LaunchGate {
    static func destination(onboardingDone: Bool) -> LaunchDestination {
        guard onboardingDone else { return .onboarding }
        return .today
    }
}

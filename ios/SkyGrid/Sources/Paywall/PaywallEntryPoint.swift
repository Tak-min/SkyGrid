import Foundation

enum PaywallEntryPoint {
    case onboarding(profile: PersonalizationProfile, wakeGoalMinutes: Int)
    case home
    case archive
    case settings
    /// A value-first reminder shown only after a person has built a real record.
    /// It is never used on launch or while the camera flow is active.
    case ritualMilestone(captureCount: Int)

    var headline: String {
        switch self {
        case .onboarding(let profile, let wakeGoalMinutes):
            return PersonalizedMorningPlanBuilder.make(profile: profile, wakeGoalMinutes: wakeGoalMinutes).proLead
        case .home:
            return "Choose the plan that keeps your mornings in view."
        case .archive:
            return "Keep every morning in one continuous Sky Grid."
        case .settings:
            return "Keep the long view of your mornings."
        case .ritualMilestone(let captureCount):
            return "\(captureCount) mornings in. Keep the whole sky record."
        }
    }

    var isAutomaticReminder: Bool {
        if case .ritualMilestone = self { return true }
        return false
    }

    /// A small, fixed taxonomy for aggregate funnel measurement. It never
    /// contains personalized onboarding answers or account data.
    var analyticsName: String {
        switch self {
        case .onboarding: "onboarding"
        case .home: "today"
        case .archive: "archive"
        case .settings: "settings"
        case .ritualMilestone: "ritual_milestone"
        }
    }

    /// A stale or unavailable entitlement check must be re-verified before an
    /// automatic reminder offers a new purchase. Manual entry points remain
    /// available so people can restore or inspect plans when they choose.
    var requiresEntitlementVerification: Bool {
        isAutomaticReminder
    }

    /// Local onboarding answers change only the explanation of the same archive
    /// value; they never change price, eligibility, plan terms, or access.
    var personalizedValueNote: String? {
        guard case .onboarding(let profile, _) = self else { return nil }
        switch profile.frequency ?? .mostMornings {
        case .mostMornings:
            return "Keep the mornings you return to in one complete record."
        case .weekdays:
            return "Keep the weekday rhythm you build in one continuous record."
        case .wheneverItFits:
            return "Keep every sky you make time for, even when the weeks change."
        }
    }

    var firstArchiveBenefit: (title: String, detail: String) {
        guard case .onboarding(let profile, _) = self else {
            return (
                "Your full archive",
                "Open every sky photo beyond the Free 30-day view."
            )
        }

        switch profile.intent ?? .steadierRhythm {
        case .steadierRhythm:
            return (
                "See your rhythm take shape",
                "Keep every morning beyond the Free 30-day view in one continuous record."
            )
        case .moreOutside:
            return (
                "Keep the changing light",
                "Return to every sky beyond the Free 30-day view, whenever you need a little outside."
            )
        case .seasonalRecord:
            return (
                "Keep the whole season",
                "Open every sky beyond the Free 30-day view as the year changes colour."
            )
        }
    }
}

/// Controls the cadence of *automatic* upgrade reminders. Manual plan, Settings,
/// and locked-archive entry points remain available whenever a person asks for
/// them; this policy only protects the daily ritual from unrelated interruptions.
enum AutomaticPaywallPresentationPolicy {
    static let minimumCompletedCaptures = 3
    static let completedCapturesBetweenPrompts = 3
    static let calendarDaysBetweenPrompts = 3
    static let snoozeInterval: TimeInterval = 14 * 24 * 60 * 60

    static func shouldPresent(
        entitlementStatus: EntitlementStatus,
        completedCaptureCount: Int,
        lastPromptedCaptureCount: Int?,
        lastPromptedLocalDate: LocalDate?,
        captureLocalDate: LocalDate,
        snoozedUntil: Date?,
        now: Date
    ) -> Bool {
        // A completed capture can create a meaningful moment to show value for
        // both a confirmed Free user and a temporarily unresolved entitlement.
        // PaywallView performs one fresh verification before it exposes purchase
        // controls in the unresolved case.
        guard entitlementStatus != .subscribed,
              completedCaptureCount >= minimumCompletedCaptures,
              snoozedUntil.map({ $0 <= now }) ?? true
        else { return false }

        guard let lastPromptedCaptureCount, let lastPromptedLocalDate else {
            return true
        }

        let hasCapturedEnough = completedCaptureCount >= lastPromptedCaptureCount + completedCapturesBetweenPrompts
        let hasWaitedLongEnough = lastPromptedLocalDate.daysUntil(captureLocalDate) >= calendarDaysBetweenPrompts
        return hasCapturedEnough || hasWaitedLongEnough
    }

    static func snoozeUntil(afterConsecutiveDismissals count: Int, now: Date) -> Date? {
        guard count >= 2 else { return nil }
        return now.addingTimeInterval(snoozeInterval)
    }
}

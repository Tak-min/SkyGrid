import Foundation

enum PaywallEntryPoint {
    case onboarding(profile: PersonalizationProfile, wakeGoalMinutes: Int)
    case home
    case archive
    case settings
    /// A value-first reminder shown only after a person has built a real record.
    /// It is never used on launch or while the camera flow is active.
    case ritualMilestone(captureCount: Int)
    /// The one automatic offer that replaced `ritualMilestone` as the sole
    /// capture-driven reminder (2026-08-10, owner's decision — see
    /// `FirstUnlockPaywallPolicy`): fires once, the moment a buddy is first
    /// mutually revealed, never on a capture-count cadence.
    case firstUnlock
    /// The cadenced automatic reminder for someone with **zero accepted buddies**
    /// (`SoloMorningPaywallPolicy`). `.firstUnlock` structurally never fires for
    /// this person — there is no buddy relationship to unlock — so this is their
    /// only automatic offer.
    case soloMorning(captureCount: Int)

    // Routed through `L10n.string(_:)`: these are stored `String` properties, not
    // `Text("literal")` call sites, so automatic String Catalog key matching does
    // not apply (see `dev-notes/localization-en-ja-stage2_*.md`).
    var headline: String {
        switch self {
        case .onboarding(let profile, let wakeGoalMinutes):
            return PersonalizedMorningPlanBuilder.make(profile: profile, wakeGoalMinutes: wakeGoalMinutes).proLead
        case .home:
            return L10n.string("paywall.entry.headline.home")
        case .archive:
            return L10n.string("paywall.entry.headline.archive")
        case .settings:
            return L10n.string("paywall.entry.headline.settings")
        case .ritualMilestone(let captureCount):
            return String(format: L10n.string("paywall.entry.headline.ritualMilestone"), captureCount)
        case .firstUnlock:
            return L10n.string("paywall.entry.headline.firstUnlock")
        case .soloMorning(let captureCount):
            return String(format: L10n.string("paywall.entry.headline.soloMorning"), captureCount)
        }
    }

    var isAutomaticReminder: Bool {
        switch self {
        case .ritualMilestone, .firstUnlock, .soloMorning: true
        default: false
        }
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
        case .firstUnlock: "first_unlock"
        case .soloMorning: "solo_morning"
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
            return L10n.string("paywall.entry.valueNote.mostMornings")
        case .weekdays:
            return L10n.string("paywall.entry.valueNote.weekdays")
        case .wheneverItFits:
            return L10n.string("paywall.entry.valueNote.wheneverItFits")
        }
    }

    var firstArchiveBenefit: (title: String, detail: String) {
        guard case .onboarding(let profile, _) = self else {
            return (
                L10n.string("paywall.entry.archiveBenefit.default.title"),
                L10n.string("paywall.entry.archiveBenefit.default.detail")
            )
        }

        switch profile.intent ?? .steadierRhythm {
        case .steadierRhythm:
            return (
                L10n.string("paywall.entry.archiveBenefit.steadierRhythm.title"),
                L10n.string("paywall.entry.archiveBenefit.steadierRhythm.detail")
            )
        case .moreOutside:
            return (
                L10n.string("paywall.entry.archiveBenefit.moreOutside.title"),
                L10n.string("paywall.entry.archiveBenefit.moreOutside.detail")
            )
        case .seasonalRecord:
            return (
                L10n.string("paywall.entry.archiveBenefit.seasonalRecord.title"),
                L10n.string("paywall.entry.archiveBenefit.seasonalRecord.detail")
            )
        }
    }
}

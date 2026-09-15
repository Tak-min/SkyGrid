import Foundation

/// A deliberately small, on-device-only set of preferences. The questions shape
/// onboarding copy and defaults; they are neither uploaded nor used for ad targeting.
enum MorningIntent: String, CaseIterable, Codable, Sendable, Identifiable {
    case steadierRhythm
    case moreOutside
    case seasonalRecord

    var id: String { rawValue }

    // Routed through `L10n.string(_:)`: these are stored `String` properties
    // consumed via `Text(option.title)`, not `Text("literal")` call sites, so
    // automatic String Catalog key matching does not apply (see
    // `dev-notes/localization-en-ja-stage2_*.md`).
    var title: String {
        switch self {
        case .steadierRhythm: return L10n.string("onboarding.intent.steadierRhythm.title")
        case .moreOutside: return L10n.string("onboarding.intent.moreOutside.title")
        case .seasonalRecord: return L10n.string("onboarding.intent.seasonalRecord.title")
        }
    }

    var detail: String {
        switch self {
        case .steadierRhythm: return L10n.string("onboarding.intent.steadierRhythm.detail")
        case .moreOutside: return L10n.string("onboarding.intent.moreOutside.detail")
        case .seasonalRecord: return L10n.string("onboarding.intent.seasonalRecord.detail")
        }
    }
}

enum RitualPace: String, CaseIterable, Codable, Sendable, Identifiable {
    case gentle
    case structured
    case flexible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle: return L10n.string("onboarding.pace.gentle.title")
        case .structured: return L10n.string("onboarding.pace.structured.title")
        case .flexible: return L10n.string("onboarding.pace.flexible.title")
        }
    }

    var detail: String {
        switch self {
        case .gentle: return L10n.string("onboarding.pace.gentle.detail")
        case .structured: return L10n.string("onboarding.pace.structured.detail")
        case .flexible: return L10n.string("onboarding.pace.flexible.detail")
        }
    }
}

enum RitualFrequency: String, CaseIterable, Codable, Sendable, Identifiable {
    case mostMornings
    case weekdays
    case wheneverItFits

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mostMornings: return L10n.string("onboarding.frequency.mostMornings.title")
        case .weekdays: return L10n.string("onboarding.frequency.weekdays.title")
        case .wheneverItFits: return L10n.string("onboarding.frequency.wheneverItFits.title")
        }
    }

    var detail: String {
        switch self {
        case .mostMornings: return L10n.string("onboarding.frequency.mostMornings.detail")
        case .weekdays: return L10n.string("onboarding.frequency.weekdays.detail")
        case .wheneverItFits: return L10n.string("onboarding.frequency.wheneverItFits.detail")
        }
    }
}

enum RitualPrivacy: String, CaseIterable, Codable, Sendable, Identifiable {
    case privateRitual
    case shareWithBuddy
    case decideLater

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privateRitual: return L10n.string("onboarding.privacy.privateRitual.title")
        case .shareWithBuddy: return L10n.string("onboarding.privacy.shareWithBuddy.title")
        case .decideLater: return L10n.string("onboarding.privacy.decideLater.title")
        }
    }

    var detail: String {
        switch self {
        case .privateRitual: return L10n.string("onboarding.privacy.privateRitual.detail")
        case .shareWithBuddy: return L10n.string("onboarding.privacy.shareWithBuddy.detail")
        case .decideLater: return L10n.string("onboarding.privacy.decideLater.detail")
        }
    }
}

enum ReminderPreference: String, CaseIterable, Codable, Sendable, Identifiable {
    case noReminder
    case gentleReminder
    case scheduledAlarm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noReminder: return L10n.string("onboarding.reminder.noReminder.title")
        case .gentleReminder: return L10n.string("onboarding.reminder.gentleReminder.title")
        case .scheduledAlarm: return L10n.string("onboarding.reminder.scheduledAlarm.title")
        }
    }

    var detail: String {
        switch self {
        case .noReminder: return L10n.string("onboarding.reminder.noReminder.detail")
        case .gentleReminder: return L10n.string("onboarding.reminder.gentleReminder.detail")
        case .scheduledAlarm: return L10n.string("onboarding.reminder.scheduledAlarm.detail")
        }
    }
}

/// Preference answers stay on-device and only shape copy, defaults, and the
/// ordering of truthful archive benefits. They never affect price, eligibility,
/// duration, or which features a plan includes.
///
/// Every answer starts unselected (`nil`) — the onboarding questions must never
/// arrive with an option already checked, since that reads as the app having
/// already decided for the person. `PersonalizedMorningPlanBuilder` and
/// `PaywallEntryPoint` fall back to the same copy the old hardcoded defaults used
/// to produce when an answer was never given.
struct PersonalizationProfile: Equatable, Codable, Sendable {
    var intent: MorningIntent?
    var pace: RitualPace?
    var frequency: RitualFrequency?
    var privacy: RitualPrivacy?
    var reminder: ReminderPreference?

    init(
        intent: MorningIntent? = nil,
        pace: RitualPace? = nil,
        frequency: RitualFrequency? = nil,
        privacy: RitualPrivacy? = nil,
        reminder: ReminderPreference? = nil
    ) {
        self.intent = intent
        self.pace = pace
        self.frequency = frequency
        self.privacy = privacy
        self.reminder = reminder
    }

    private enum CodingKeys: String, CodingKey {
        case intent
        case pace
        case frequency
        case privacy
        case reminder
    }

    /// Existing installations stored only the first three answers (or, before this
    /// change, always stored a non-optional default). Decoding each key
    /// independently preserves whatever was actually answered.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            intent: try values.decodeIfPresent(MorningIntent.self, forKey: .intent),
            pace: try values.decodeIfPresent(RitualPace.self, forKey: .pace),
            frequency: try values.decodeIfPresent(RitualFrequency.self, forKey: .frequency),
            privacy: try values.decodeIfPresent(RitualPrivacy.self, forKey: .privacy),
            reminder: try values.decodeIfPresent(ReminderPreference.self, forKey: .reminder)
        )
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeIfPresent(intent, forKey: .intent)
        try values.encodeIfPresent(pace, forKey: .pace)
        try values.encodeIfPresent(frequency, forKey: .frequency)
        try values.encodeIfPresent(privacy, forKey: .privacy)
        try values.encodeIfPresent(reminder, forKey: .reminder)
    }
}

struct PersonalizedMorningPlan: Equatable, Sendable {
    let headline: String
    let recommendation: String
    let privacyNote: String
    let proLead: String
}

enum PersonalizedMorningPlanBuilder {
    static func make(profile: PersonalizationProfile, wakeGoalMinutes: Int) -> PersonalizedMorningPlan {
        let time = String(format: "%02d:%02d", wakeGoalMinutes / 60, wakeGoalMinutes % 60)
        let headline: String
        let proLead: String

        // An unanswered question falls back to the same copy the old hardcoded
        // default used to produce — the profile only ever refines this baseline,
        // it never blocks reaching it.
        switch profile.intent ?? .steadierRhythm {
        case .steadierRhythm:
            headline = String(format: L10n.string("onboarding.plan.headline.steadierRhythm"), time)
            proLead = L10n.string("onboarding.plan.proLead.steadierRhythm")
        case .moreOutside:
            headline = String(format: L10n.string("onboarding.plan.headline.moreOutside"), time)
            proLead = L10n.string("onboarding.plan.proLead.moreOutside")
        case .seasonalRecord:
            headline = String(format: L10n.string("onboarding.plan.headline.seasonalRecord"), time)
            proLead = L10n.string("onboarding.plan.proLead.seasonalRecord")
        }

        let paceRecommendation: String
        switch profile.pace ?? .gentle {
        case .gentle:
            paceRecommendation = L10n.string("onboarding.plan.pace.gentle")
        case .structured:
            paceRecommendation = L10n.string("onboarding.plan.pace.structured")
        case .flexible:
            paceRecommendation = L10n.string("onboarding.plan.pace.flexible")
        }

        let frequencyRecommendation: String
        switch profile.frequency ?? .mostMornings {
        case .mostMornings:
            frequencyRecommendation = L10n.string("onboarding.plan.frequency.mostMornings")
        case .weekdays:
            frequencyRecommendation = L10n.string("onboarding.plan.frequency.weekdays")
        case .wheneverItFits:
            frequencyRecommendation = L10n.string("onboarding.plan.frequency.wheneverItFits")
        }

        let privacyNote: String
        switch profile.privacy ?? .privateRitual {
        case .privateRitual:
            privacyNote = L10n.string("onboarding.plan.privacy.privateRitual")
        case .shareWithBuddy:
            privacyNote = L10n.string("onboarding.plan.privacy.shareWithBuddy")
        case .decideLater:
            privacyNote = L10n.string("onboarding.plan.privacy.decideLater")
        }

        return PersonalizedMorningPlan(
            headline: headline,
            recommendation: "\(paceRecommendation) \(frequencyRecommendation)",
            privacyNote: privacyNote,
            proLead: proLead
        )
    }
}

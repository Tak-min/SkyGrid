import Foundation

/// A deliberately small, on-device-only set of preferences. The questions shape
/// onboarding copy and defaults; they are neither uploaded nor used for ad targeting.
enum MorningIntent: String, CaseIterable, Codable, Sendable, Identifiable {
    case steadierRhythm
    case moreOutside
    case seasonalRecord

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steadierRhythm: return "A steadier rhythm"
        case .moreOutside: return "More time outside"
        case .seasonalRecord: return "A record of the seasons"
        }
    }

    var detail: String {
        switch self {
        case .steadierRhythm: return "A small reason to get up at the same time."
        case .moreOutside: return "One quiet moment under the open sky."
        case .seasonalRecord: return "A year that gradually becomes visible."
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
        case .gentle: return "Gentle"
        case .structured: return "Structured"
        case .flexible: return "Flexible"
        }
    }

    var detail: String {
        switch self {
        case .gentle: return "A reminder, never a reprimand."
        case .structured: return "A clear time to begin the day."
        case .flexible: return "Room for the mornings that change."
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
        case .mostMornings: return "Most mornings"
        case .weekdays: return "Weekdays"
        case .wheneverItFits: return "When it fits"
        }
    }

    var detail: String {
        switch self {
        case .mostMornings: return "A small daily mark, with room to miss one."
        case .weekdays: return "A consistent start to the days that need it."
        case .wheneverItFits: return "A record that grows at its own pace."
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
        case .privateRitual: return "Just for me"
        case .shareWithBuddy: return "With a buddy, later"
        case .decideLater: return "I’ll decide later"
        }
    }

    var detail: String {
        switch self {
        case .privateRitual: return "Your sky stays your own by default."
        case .shareWithBuddy: return "Buddies are optional, and reciprocal."
        case .decideLater: return "Nothing needs to be decided today."
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
        case .noReminder: return "No reminder"
        case .gentleReminder: return "A gentle reminder"
        case .scheduledAlarm: return "A scheduled alarm"
        }
    }

    var detail: String {
        switch self {
        case .noReminder: return "I’ll open Sky Grid when I’m ready."
        case .gentleReminder: return "A quiet nudge at the time I choose."
        case .scheduledAlarm: return "A dedicated start to the morning."
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
            headline = "A quieter way to keep \(time)."
            proLead = "Keep the whole record as your rhythm takes shape."
        case .moreOutside:
            headline = "One small reason to step outside at \(time)."
            proLead = "Keep the changing light beyond the last 30 days."
        case .seasonalRecord:
            headline = "A year of skies begins at \(time)."
            proLead = "Let every morning stay in the same long-view grid."
        }

        let paceRecommendation: String
        switch profile.pace ?? .gentle {
        case .gentle:
            paceRecommendation = "Keep it gentle: one photo is enough."
        case .structured:
            paceRecommendation = "Let the time you choose lead to one simple first action."
        case .flexible:
            paceRecommendation = "Keep it light. A missed morning is simply an empty square."
        }

        let frequencyRecommendation: String
        switch profile.frequency ?? .mostMornings {
        case .mostMornings:
            frequencyRecommendation = "Most mornings are plenty."
        case .weekdays:
            frequencyRecommendation = "Keep weekends open and weekdays intentional."
        case .wheneverItFits:
            frequencyRecommendation = "Return whenever the sky gives you a minute."
        }

        let privacyNote: String
        switch profile.privacy ?? .privateRitual {
        case .privateRitual:
            privacyNote = "Your first sky is private. Sharing is always your choice."
        case .shareWithBuddy:
            privacyNote = "Add a buddy only when the ritual already feels like yours."
        case .decideLater:
            privacyNote = "You can decide about buddies after you have a few skies of your own."
        }

        return PersonalizedMorningPlan(
            headline: headline,
            recommendation: "\(paceRecommendation) \(frequencyRecommendation)",
            privacyNote: privacyNote,
            proLead: proLead
        )
    }
}

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

struct PersonalizationProfile: Equatable, Codable, Sendable {
    var intent: MorningIntent = .steadierRhythm
    var pace: RitualPace = .gentle
    var privacy: RitualPrivacy = .privateRitual
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

        switch profile.intent {
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

        let recommendation: String
        switch profile.pace {
        case .gentle:
            recommendation = "Use a gentle alarm, then take one photo. Nothing else is required."
        case .structured:
            recommendation = "Let the alarm open a simple first action: the camera, then the day."
        case .flexible:
            recommendation = "Keep the ritual light. A missed morning is simply an empty square."
        }

        let privacyNote: String
        switch profile.privacy {
        case .privateRitual:
            privacyNote = "Your first sky is private. Sharing is always your choice."
        case .shareWithBuddy:
            privacyNote = "Add a buddy only when the ritual already feels like yours."
        case .decideLater:
            privacyNote = "You can decide about buddies after you have a few skies of your own."
        }

        return PersonalizedMorningPlan(
            headline: headline,
            recommendation: recommendation,
            privacyNote: privacyNote,
            proLead: proLead
        )
    }
}

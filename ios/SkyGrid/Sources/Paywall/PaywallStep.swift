import Foundation

/// `rawValue` doubles as the fixed analytics taxonomy for `stepViewed`/`dismissed` —
/// do not change a case name without updating the funnel report that reads it.
enum PaywallStep: String, CaseIterable, Equatable {
    case value
    case features
    case plan
    case secondChance = "second_chance"
}

/// The ordered sequence of steps a paywall presentation walks through. Standard
/// flows end at `.plan`; an eligible close can append `.secondChance` at runtime.
struct PaywallFlow: Equatable {
    let steps: [PaywallStep]

    /// Only the automatic capture-driven reminders (`.ritualMilestone`,
    /// `.firstUnlock`) skip the value step — every other entry point is already an
    /// intentional, active visit and gets the full three-step flow. See
    /// `session-handoff-paywall-alarm_2026-08-01.md` §5 for the reasoning. The same
    /// logic extends to `.firstUnlock`: a mutual reveal has already demonstrated the
    /// product's value more directly than the value step could restate it.
    static func make(
        for entryPoint: PaywallEntryPoint,
        includesSecondChance: Bool = false
    ) -> PaywallFlow {
        let standardSteps: [PaywallStep]
        switch entryPoint {
        case .ritualMilestone, .firstUnlock:
            standardSteps = [.features, .plan]
        default:
            standardSteps = [.value, .features, .plan]
        }
        return PaywallFlow(
            steps: includesSecondChance ? standardSteps + [.secondChance] : standardSteps
        )
    }

    func appendingSecondChance() -> PaywallFlow {
        guard !steps.contains(.secondChance) else { return self }
        return PaywallFlow(steps: steps + [.secondChance])
    }

    var first: PaywallStep { steps[0] }

    func next(after step: PaywallStep) -> PaywallStep? {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return nil }
        return steps[index + 1]
    }

    func previous(before step: PaywallStep) -> PaywallStep? {
        guard let index = steps.firstIndex(of: step), index > 0 else { return nil }
        return steps[index - 1]
    }

    func isFinal(_ step: PaywallStep) -> Bool {
        steps.last == step
    }

    func index(of step: PaywallStep) -> Int? {
        steps.firstIndex(of: step)
    }
}

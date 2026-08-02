import Foundation

/// `rawValue` doubles as the fixed analytics taxonomy for `stepViewed`/`dismissed` —
/// do not change a case name without updating the funnel report that reads it.
enum PaywallStep: String, CaseIterable, Equatable {
    case value
    case features
    case plan
}

/// The ordered sequence of steps a paywall presentation walks through. The final
/// step is always `.plan`: pricing is never hidden behind more than the entry
/// point's own step count.
struct PaywallFlow: Equatable {
    let steps: [PaywallStep]

    /// Only `.ritualMilestone` skips the value step — every other entry point is
    /// already an intentional, active visit and gets the full three-step flow.
    /// See `session-handoff-paywall-alarm_2026-08-01.md` §5 for the reasoning.
    static func make(for entryPoint: PaywallEntryPoint) -> PaywallFlow {
        switch entryPoint {
        case .ritualMilestone:
            PaywallFlow(steps: [.features, .plan])
        default:
            PaywallFlow(steps: [.value, .features, .plan])
        }
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

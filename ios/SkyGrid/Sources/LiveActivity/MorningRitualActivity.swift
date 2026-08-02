import ActivityKit
import Foundation

/// The only file in the app target that calls ActivityKit directly. Kept thin and
/// untested by design — every timing/should-I decision lives in
/// `MorningRitualPolicy`; this just carries its answer out.
enum MorningRitualActivity {
    static var runningLocalDateID: String? {
        Activity<MorningRitualAttributes>.activities.first?.attributes.localDateID
    }

    static func start(localDateID: String, wokeAt: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = MorningRitualAttributes(localDateID: localDateID)
        let state = MorningRitualAttributes.ContentState(status: .awaitingCapture, wokeAt: wokeAt)
        let staleDate = wokeAt.addingTimeInterval(TimeInterval(MorningRitualPolicy.morningWindowMinutes * 60))
        let content = ActivityContent(state: state, staleDate: staleDate)
        // A denied/unsupported Live Activity is not a failure of the morning
        // ritual itself — the follow-up notification still covers the nudge.
        _ = try? Activity.request(attributes: attributes, content: content)
    }

    static func end(status: MorningRitualAttributes.ContentState.Status) async {
        for activity in Activity<MorningRitualAttributes>.activities {
            let finalState = MorningRitualAttributes.ContentState(status: status, wokeAt: activity.content.state.wokeAt)
            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
    }
}

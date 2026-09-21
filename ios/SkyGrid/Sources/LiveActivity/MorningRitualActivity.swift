import ActivityKit
import Foundation
import os

/// The only file in the app target that calls ActivityKit directly. Kept thin and
/// untested by design — every timing/should-I decision lives in
/// `MorningRitualPolicy`; this just carries its answer out.
@MainActor
enum MorningRitualActivity {
    enum StartResult: Equatable {
        case started
        case alreadyRunning
        case disabled
        case failed
    }

    private static let logger = Logger(subsystem: "com.takmin.skygrid", category: "live-activity")

    static var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static var runningLocalDateID: String? {
        Activity<MorningRitualAttributes>.activities.first?.attributes.localDateID
    }

    @discardableResult
    static func start(localDateID: String, wokeAt: Date) -> StartResult {
        guard areActivitiesEnabled else { return .disabled }
        // `reconcile` can be requested by appear, scene activation, and route
        // changes in quick succession. Do not create a second activity for the
        // same morning when those hooks overlap.
        guard !Activity<MorningRitualAttributes>.activities.contains(where: {
            $0.attributes.localDateID == localDateID
        }) else { return .alreadyRunning }
        let attributes = MorningRitualAttributes(localDateID: localDateID)
        let captureBy = wokeAt.addingTimeInterval(MorningRitualAttributes.captureWindow)
        let state = MorningRitualAttributes.ContentState(
            status: .awaitingCapture,
            wokeAt: wokeAt,
            captureBy: captureBy,
            languageCode: L10n.language.rawValue
        )
        let content = ActivityContent(state: state, staleDate: captureBy, relevanceScore: 100)
        // A denied/unsupported Live Activity is not a failure of the morning
        // ritual itself — the follow-up notification still covers the nudge.
        do {
            _ = try Activity.request(attributes: attributes, content: content)
            return .started
        } catch {
            logger.error("Live Activity request failed: \(String(describing: error), privacy: .public)")
            return .failed
        }
    }

    static func end(status: MorningRitualAttributes.ContentState.Status) async {
        for activity in Activity<MorningRitualAttributes>.activities {
            let finalState = MorningRitualAttributes.ContentState(
                status: status,
                wokeAt: activity.content.state.wokeAt,
                captureBy: activity.content.state.captureBy,
                languageCode: activity.content.state.languageCode
            )
            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
    }

    static func resyncLocalizedContent() async {
        for activity in Activity<MorningRitualAttributes>.activities {
            var state = activity.content.state
            state.languageCode = L10n.language.rawValue
            await activity.update(ActivityContent(
                state: state,
                staleDate: state.captureBy,
                relevanceScore: 100
            ))
        }
    }
}

import FirebaseAnalytics
import FirebaseCore

/// The invite funnel is deliberately measured without a user ID, handle, or invite
/// code — a code is a secret (`invites.ts`'s `codeForLog()` exists for the same
/// reason server-side), so it must never reach an analytics payload even truncated.
/// These events reveal where the funnel loses people, nothing about who used it.
enum InviteAnalytics {
    enum Event: String {
        case linkCreated = "skygrid_invite_link_created"
        case linkShared = "skygrid_invite_link_shared"
        case codeCopied = "skygrid_invite_code_copied"
        case linkRevoked = "skygrid_invite_link_revoked"
        case previewViewed = "skygrid_invite_preview_viewed"
        case claimStarted = "skygrid_invite_claim_started"
        case claimResolved = "skygrid_invite_claim_resolved"
    }

    static func record(
        _ event: Event,
        previewState: InvitePreviewState? = nil,
        claimOutcome: InviteClaimOutcome? = nil
    ) {
        // UI-audit launches intentionally skip Firebase configuration. Do not turn
        // local visual checks into a network dependency or a fake event.
        guard FirebaseApp.app() != nil else { return }

        var parameters: [String: Any] = [:]
        if let previewState {
            parameters["preview_state"] = previewState.rawValue
        }
        if let claimOutcome {
            parameters["claim_outcome"] = claimOutcome.rawValue
        }
        Analytics.logEvent(event.rawValue, parameters: parameters)
    }
}

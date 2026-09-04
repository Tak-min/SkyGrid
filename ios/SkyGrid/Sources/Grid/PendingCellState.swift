import Foundation

/// The Grid's honest view of a day whose Firestore document does not exist yet but
/// whose photo is sitting in the local upload outbox (`PendingUpload`/`UploadQueue`).
/// Deliberately mirrors `PostStatusBanner`'s existing three-way `UploadState` split
/// (staged/uploading vs. failed vs. conflict) — there is intentionally no fourth
/// "looks confirmed" case. A cell in one of these states must never be counted as a
/// posted day: `GridArchiveViewModel.posts` (the only source `postedCount`/streak/
/// share-card read from) is never touched by this type, and the Firestore document
/// arriving always retires the corresponding pending state for that date.
enum PendingCellState: String, Sendable, Equatable, Hashable, CaseIterable {
    /// The photo is on-device and the outbox is actively trying to land it
    /// (`.stagedPost`, `.pendingLocal`, `.uploading`) or finished uploading Storage
    /// bytes for a document that hasn't reached the Grid's Firestore listener yet
    /// (`.done`). All four collapse into one visual state: nothing is wrong, it just
    /// isn't confirmed.
    case inFlight
    /// The write was rejected and needs an explicit retry (`.failed`/`.postFailed`).
    case retryableFailure
    /// Another document already owns this day; the photo is retained for the
    /// person to explicitly resolve (`.postConflict`).
    case needsReview

    init(uploadState: UploadState) {
        switch uploadState {
        case .stagedPost, .pendingLocal, .uploading, .done:
            self = .inFlight
        case .failed, .postFailed:
            self = .retryableFailure
        case .postConflict:
            self = .needsReview
        }
    }

    var symbolName: String {
        switch self {
        case .inFlight: return "clock.fill"
        case .retryableFailure: return "exclamationmark.arrow.circlepath"
        case .needsReview: return "exclamationmark.triangle.fill"
        }
    }

    var accessibilitySuffix: String {
        switch self {
        case .inFlight: return "sending"
        case .retryableFailure: return "needs retry"
        case .needsReview: return "needs review"
        }
    }
}

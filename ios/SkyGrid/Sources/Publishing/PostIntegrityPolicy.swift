import Foundation

/// Whether today's post document is backed by real Storage bytes, still has a
/// realistic path to get them, or is a permanent orphan — a Firestore document that
/// references an image that will never exist because nothing local can ever deliver
/// it. Firestore's `posts/{localDate}` rule forbids updating an existing document
/// (`firestore.rules`), so an orphan blocks every future capture for that day until
/// something explicitly deletes it (`OrphanedPostRecovery`).
enum TodayPostIntegrity: Sendable, Equatable {
    /// Storage holds at least one of the two objects — the record is real.
    case intact
    /// No bytes in Storage yet, but a local row can still deliver them.
    case uploadPending
    /// Not enough information to judge safely. Never act on this — in particular,
    /// never delete the post document while in this state.
    case undetermined
    /// Confirmed: no bytes in Storage, and nothing local can ever supply them.
    case orphaned
}

/// Pure decision table for `TodayPostIntegrity`, isolated from all I/O so every
/// branch is a fast, deterministic unit test — matches `MorningRitualPolicy` /
/// `AutomaticPaywallPresentationPolicy` in this codebase.
enum PostIntegrityPolicy {
    /// A `publish()` call writes the Firestore doc and enqueues the upload row as two
    /// separate, uncoordinated steps (`PostPublisher.publish`). This window gives
    /// that sequence time to finish before treating a momentary "no row yet" as
    /// orphaned.
    static let graceInterval: TimeInterval = 120

    /// Snapshot of the `PendingUpload` row (if any) tracking today's capture, reduced
    /// to only what this decision needs.
    struct QueueRow: Sendable, Equatable {
        let state: UploadState
        let fullImagePath: String
        let hasLocalFullImage: Bool
    }

    static func evaluate(
        fullImage: RemoteImagePresence,
        thumbImage: RemoteImagePresence,
        row: QueueRow?,
        postImagePath: String,
        postAge: TimeInterval,
        graceInterval: TimeInterval = graceInterval
    ) -> TodayPostIntegrity {
        // Storage is the source of truth. Either object existing proves the record
        // is real; the queue's own resume logic (`uploadIfNeeded`) finishes the
        // other half if it's still missing.
        if fullImage == .present || thumbImage == .present {
            return .intact
        }

        // An indeterminate read (offline, App Check rejected, transient failure)
        // must never be treated as proof of absence — this is the branch that keeps
        // this feature from becoming a data-loss bug for anyone temporarily unable
        // to reach Storage.
        if fullImage == .indeterminate || thumbImage == .indeterminate {
            return .undetermined
        }

        // `publish()` may still be mid-flight on another task.
        if postAge < graceInterval {
            return .undetermined
        }

        // No row at all, or a row that belongs to a *different* capture (a
        // superseded recapture, or `cancel()` already removed the row for the
        // capture that actually won the day). Neither can ever deliver this post's
        // bytes.
        guard let row, row.fullImagePath == postImagePath else {
            return .orphaned
        }

        switch row.state {
        case .pendingLocal, .uploading:
            return .uploadPending
        case .failed:
            // If the local bytes still exist, `PostStatusBanner`'s existing
            // "Retry now" is the better (non-destructive) action — it preserves the
            // original photo instead of discarding the record.
            return row.hasLocalFullImage ? .uploadPending : .orphaned
        case .done:
            // Contradiction: the row claims success but Storage disagrees. This
            // should not happen; treat it as undetermined rather than acting on a
            // state the rest of the system doesn't understand.
            return .undetermined
        }
    }
}

import SwiftUI

/// Quiet, non-alarming notice for a photo still in the upload queue — never silent,
/// never scary. A missed morning's photo can't be recreated, so failures always get a
/// visible retry affordance (blueprint §5.3).
struct PostStatusBanner: View {
    let pending: [PendingUploadSummary]
    let today: LocalDate
    let onRetry: () -> Void
    let onDiscardStale: (String) -> Void

    /// A failed/rejected row whose `localDate` has aged past what
    /// `firestore.rules` will still accept — see `PostCreateWindowPolicy`.
    /// Retrying this specific row can never succeed, so it gets its own message
    /// and an explicit "Remove" action instead of the generic retry banner
    /// below (which would otherwise offer a "Retry now" that silently never
    /// works forever — the bug this fixes).
    private var staleUnrecoverable: PendingUploadSummary? {
        pending.first { isStaleAndUnrecoverable($0) }
    }

    private func isStaleAndUnrecoverable(_ summary: PendingUploadSummary) -> Bool {
        guard summary.state == .failed || summary.state == .postFailed,
              let localDate = LocalDate(docID: summary.localDateID)
        else { return false }
        return PostCreateWindowPolicy.isTooOldToRetry(localDate: localDate, today: today)
    }

    var body: some View {
        if pending.contains(where: { $0.state == .postConflict }) {
            Text(L10n.string("A saved photo needs review before it can send."))
                .font(SGFont.caption())
                .foregroundStyle(SGT.ink2)
        } else if let stale = staleUnrecoverable {
            HStack(spacing: SGSpacing.md) {
                Text(L10n.string("A saved photo is too old to send now"))
                    .font(SGFont.caption())
                    .foregroundStyle(SGT.ink2)
                Spacer()
                Button(L10n.string("Remove"), role: .destructive) { onDiscardStale(stale.queueID) }
                    .font(SGFont.caption(13))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .quietCard()
        } else if pending.contains(where: { $0.state == .failed || $0.state == .postFailed }) {
            HStack(spacing: SGSpacing.md) {
                Text(L10n.string("Photo is saved on this device"))
                    .font(SGFont.caption())
                    .foregroundStyle(SGT.ink2)
                Spacer()
                Button(L10n.string("Retry now"), action: onRetry)
                    .font(SGFont.caption(13))
                    .foregroundStyle(SGT.ink)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .quietCard()
        } else if pending.contains(where: { $0.state == .stagedPost }) {
            Text(L10n.string("Saving your post…"))
                .font(SGFont.caption())
                .foregroundStyle(SGT.ink3)
        } else if pending.contains(where: { $0.state == .pendingLocal || $0.state == .uploading }) {
            Text(L10n.string("Sending…"))
                .font(SGFont.caption())
                .foregroundStyle(SGT.ink3)
        }
    }
}

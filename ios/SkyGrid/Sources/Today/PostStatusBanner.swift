import SwiftUI

/// Quiet, non-alarming notice for a photo still in the upload queue — never silent,
/// never scary. A missed morning's photo can't be recreated, so failures always get a
/// visible retry affordance (blueprint §5.3).
struct PostStatusBanner: View {
    let pending: [PendingUploadSummary]
    let onRetry: () -> Void

    var body: some View {
        if pending.contains(where: { $0.state == .failed }) {
            HStack(spacing: SGSpacing.md) {
                Text("Photo is waiting to send")
                    .font(SGFont.caption())
                    .foregroundStyle(SGT.ink2)
                Spacer()
                Button("Retry now", action: onRetry)
                    .font(SGFont.caption(13))
                    .foregroundStyle(SGT.ink)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .quietCard()
        } else if pending.contains(where: { $0.state == .pendingLocal || $0.state == .uploading }) {
            Text("Sending…")
                .font(SGFont.caption())
                .foregroundStyle(SGT.ink3)
        }
    }
}

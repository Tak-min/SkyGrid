import SwiftUI

/// Quiet, non-alarming notice for a photo still in the upload queue — never silent,
/// never scary. A missed morning's photo can't be recreated, so failures always get a
/// visible retry affordance (blueprint §5.3).
struct PostStatusBanner: View {
    let pending: [PendingUploadSummary]

    var body: some View {
        if pending.contains(where: { $0.state == .failed }) {
            Text("Not sent yet · trying again")
                .font(SGFont.caption())
                .foregroundStyle(SGT.ink2)
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

#if DEBUG
import SwiftUI

/// Uses production presentation leases and the actual reward view. All data is
/// synthetic; no service graph, upload, entitlement or account is constructed.
struct PresentationFlowAuditView: View {
    @State private var presentations = RootPresentationCoordinator()
    @State private var pendingInvite = false
    @State private var pendingMilestone = false
    @State private var finished = false
    private let signal = RevealSignal()

    var body: some View {
        VStack(spacing: 24) {
            Text(finished ? "Morning is ready" : "Presentation regression")
            Button("Start saved-sky reward") {
                finished = false
                pendingInvite = true
                pendingMilestone = true
                presentations.present(.reward(RewardMoment(
                    localDate: LocalDate(year: 2026, month: 9, day: 6),
                    skyColor: SkyColor(uncheckedHex: "#64B4DC"),
                    thumbnailData: nil
                )))
            }
            .buttonStyle(SkyPrimaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGT.background)
        .fullScreenCover(item: presentations.binding(fullScreen: true), onDismiss: didDismiss) { presentation in
            if case .reward(let moment) = presentation {
                RewardOverlayView(moment: moment, revealSignal: signal, imageFetching: AuditNoImageFetcher()) {
                    presentations.dismiss()
                }
            } else {
                VStack(spacing: 24) {
                    Text("Day one — presentation survived")
                    Button("Finish morning") { presentations.dismiss() }
                }
            }
        }
        .sheet(item: presentations.binding(fullScreen: false), onDismiss: didDismiss) { _ in
            VStack(spacing: 24) {
                Text("Pending invite")
                Button("Dismiss pending invite") { presentations.dismiss() }
            }
        }
    }

    private func didDismiss() {
        presentations.didDismiss()
        if pendingInvite {
            pendingInvite = false
            presentations.present(.invite(InviteCode(raw: "123456789A")!))
        } else if pendingMilestone {
            pendingMilestone = false
            // A full-screen camera token exercises the exact same UIKit carrier
            // as the milestone without fabricating a persisted post.
            presentations.present(.camera)
        } else {
            finished = true
        }
    }
}

private struct AuditNoImageFetcher: ImageFetching {
    func fetchImage(path: String) async throws -> Data { throw CancellationError() }
}
#endif

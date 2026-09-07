import SwiftUI
import UIKit

/// Lives inside the Buddies tab, in the `hasHandle == true` branch, and (since
/// VISION.md Bet 3) inside `MilestoneView` when the moment already carries a handle —
/// a handle is required before `createInvite` will succeed (`MissingHandleError`
/// server-side), so this card only ever appears once one exists. `placement`
/// distinguishes the two call sites in analytics without a second event name.
struct InviteLinkCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel: InviteLinkViewModel
    @State private var showCopiedConfirmation = false
    @State private var showRevokeConfirmation = false
    private let placement: InviteAnalytics.Placement

    init(inviteRepository: any InviteRepository, placement: InviteAnalytics.Placement = .buddiesTab) {
        _viewModel = State(initialValue: InviteLinkViewModel(inviteRepository: inviteRepository, placement: placement))
        self.placement = placement
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            Label("INVITE A BUDDY", systemImage: "link")
                .font(SGFont.caption(11))
                .tracking(1.2)
                .foregroundStyle(SGT.ink3)

            switch viewModel.linkState {
            case .loading:
                HStack(spacing: SGSpacing.sm) {
                    ProgressView()
                    Text("Preparing your invite link…")
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink2)
                }
            case .ready(let link):
                readyContent(link: link)
            case .revoked:
                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    Text("This link no longer works.")
                        .font(SGFont.body(15))
                        .foregroundStyle(SGT.ink)
                    Button("Get a new link") { Task { await viewModel.load() } }
                        .font(SGFont.body(15))
                        .foregroundStyle(SGT.ink)
                        .frame(minHeight: 44)
                }
            case .failed(let message):
                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    Text(message)
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink2)
                    Button("Try again") { Task { await viewModel.load() } }
                        .font(SGFont.body(15))
                        .foregroundStyle(SGT.ink)
                        .frame(minHeight: 44)
                }
            }
        }
        .padding(SGSpacing.md)
        .background(SGT.fill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(SGT.rule, lineWidth: 1)
        }
        .task { await viewModel.load() }
        .alert("Stop sharing this link?", isPresented: $showRevokeConfirmation) {
            Button("Stop sharing", role: .destructive) { Task { await viewModel.revoke() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Anyone who already has this code will no longer be able to use it.")
        }
    }

    @ViewBuilder
    private func readyContent(link: InviteLink) -> some View {
        Text(link.code.formatted)
            .font(SGFont.numeric(22, weight: .semibold))
            .foregroundStyle(SGT.ink)
            .accessibilityLabel("Invite code \(link.code.formatted)")

        Text("Share this link with one trusted person. It works until they open it.")
            .font(SGFont.caption(13))
            .foregroundStyle(SGT.ink2)

        inviteActionsLayout {
            ShareLink(item: link.url) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(SGFont.body(15))
            }
            .buttonStyle(.borderedProminent)
            // See `InviteClaimView`: `SGT.ink` adapts and is a text colour, so as a
            // prominent fill it went white-on-white in dark mode.
            .tint(SGT.accent)
            .foregroundStyle(SGT.accentInk)
            .simultaneousGesture(TapGesture().onEnded {
                // ShareLink has no completion callback, only this tap — recorded on
                // the intent to share, not confirmed delivery.
                InviteAnalytics.record(.linkShared, placement: placement)
            })

            Button {
                UIPasteboard.general.string = link.code.formatted
                showCopiedConfirmation = true
                InviteAnalytics.record(.codeCopied, placement: placement)
            } label: {
                Label(showCopiedConfirmation ? "Copied" : "Copy code", systemImage: showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                    .font(SGFont.body(15))
            }
            .buttonStyle(.bordered)
        }
        .frame(minHeight: 44)
        .animation(.default, value: showCopiedConfirmation)
        .task(id: showCopiedConfirmation) {
            // Installing a real app from a link loses the code (no deferred deep
            // link), so "Copy code" is the recovery path for a recipient to paste it
            // back in after they install — the confirmation just needs to be seen,
            // not to persist.
            guard showCopiedConfirmation else { return }
            try? await Task.sleep(for: .seconds(2))
            showCopiedConfirmation = false
        }

        Button("Stop sharing this link", role: .destructive) {
            showRevokeConfirmation = true
        }
        .font(SGFont.caption(13))
        .disabled(viewModel.isRevoking)
    }

    private var inviteActionsLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: SGSpacing.sm))
        } else {
            AnyLayout(HStackLayout(spacing: SGSpacing.sm))
        }
    }
}

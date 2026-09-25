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
    /// Fires on the same tap that records `.linkShared` below — SwiftUI's
    /// `ShareLink` has no completion callback, so "tapped Share" is the best
    /// available signal that the person took the link out of the app. Used by
    /// `OnboardingInviteView` to require that tap (not just link generation)
    /// before onboarding can continue.
    private let onShareIntent: (() -> Void)?

    init(
        inviteRepository: any InviteRepository,
        placement: InviteAnalytics.Placement = .buddiesTab,
        onLinkReady: ((InviteLink) -> Void)? = nil,
        onShareIntent: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: InviteLinkViewModel(
            inviteRepository: inviteRepository,
            placement: placement,
            onLinkReady: onLinkReady
        ))
        self.placement = placement
        self.onShareIntent = onShareIntent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            Text(L10n.string("invite.header"))
                .font(SGFont.caption(11))
                .tracking(1.2)
                .foregroundStyle(SGT.accentSecondary)

            switch viewModel.linkState {
            case .loading:
                HStack(spacing: SGSpacing.sm) {
                    ProgressView()
                    Text(L10n.string("invite.preparing"))
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink2)
                }
            case .ready(let link):
                readyContent(link: link)
            case .revoked:
                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    Text(L10n.string("invite.linkRevoked"))
                        .font(SGFont.body(15))
                        .foregroundStyle(SGT.ink)
                    Button(L10n.string("invite.getNewLink")) { Task { await viewModel.load() } }
                        .font(SGFont.body(15))
                        .foregroundStyle(SGT.accent)
                        .frame(minHeight: 44)
                }
            case .failed(let message):
                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    Text(message)
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink2)
                    Button(L10n.string("invite.tryAgain")) { Task { await viewModel.load() } }
                        .font(SGFont.body(15))
                        .foregroundStyle(SGT.accent)
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
        .alert(L10n.string("invite.alert.revokeTitle"), isPresented: $showRevokeConfirmation) {
            Button(L10n.string("invite.alert.stopSharing"), role: .destructive) { Task { await viewModel.revoke() } }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("invite.alert.revokeMessage"))
        }
    }

    @ViewBuilder
    private func readyContent(link: InviteLink) -> some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            Text(L10n.string("invite.groupCode"))
                .font(SGFont.caption(11))
                .tracking(1.0)
                .foregroundStyle(SGT.ink2)

            HStack(spacing: SGSpacing.sm) {
                Text(link.code.formatted)
                    .font(SGFont.numeric(24, weight: .semibold))
                    .foregroundStyle(SGT.ink)
                    .accessibilityLabel(String(format: L10n.string("invite.inviteCodeAccessibility"), link.code.formatted))

                Spacer()

                Button {
                    UIPasteboard.general.string = link.code.formatted
                    showCopiedConfirmation = true
                    InviteAnalytics.record(.codeCopied, placement: placement)
                } label: {
                    Image(systemName: showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(SGT.accentSecondary)
                .frame(minHeight: 44)
                .animation(.default, value: showCopiedConfirmation)
                .task(id: showCopiedConfirmation) {
                    guard showCopiedConfirmation else { return }
                    try? await Task.sleep(for: .seconds(2))
                    showCopiedConfirmation = false
                }
            }
            .padding(SGSpacing.md)
            .background(Color.clear)
        }

        ShareLink(item: shareText(for: link)) {
            HStack(spacing: SGSpacing.sm) {
                Image(systemName: "square.and.arrow.up")
                Text(L10n.string("invite.shareLink"))
            }
            .font(SGFont.body(15))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(SkyPrimaryButtonStyle())
        .simultaneousGesture(TapGesture().onEnded {
            // ShareLink has no completion callback, only this tap — recorded on
            // the intent to share, not confirmed delivery.
            InviteAnalytics.record(.linkShared, placement: placement)
            onShareIntent?()
        })

        Button(L10n.string("invite.stopSharing"), role: .destructive) {
            showRevokeConfirmation = true
        }
        .font(SGFont.caption(13))
        .foregroundStyle(.red)
        .disabled(viewModel.isRevoking)
    }

    /// Some social apps drop the universal-link handoff when a URL is shared on
    /// its own. Keeping the canonical URL and a readable code in the same plain
    /// text payload gives the recipient a reliable recovery path in Sky Grid.
    private func shareText(for link: InviteLink) -> String {
        "Join me on Sky Grid — we can reveal our morning skies together.\n\nInvite code: \(link.code.formatted)\n\(link.url.absoluteString)"
    }
}

/// Lets a recipient recover an invite when Instagram, LINE, or another social
/// app strips the universal-link handoff. The sender's share text includes this
/// same readable code, so the recipient can paste or type it after installing.
struct InviteCodeRecoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var codeText = ""
    @State private var errorMessage: String?
    @State private var claimCode: InviteCode?

    let uid: String
    let inviteRepository: any InviteRepository
    let userRepository: any UserRepository

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SGSpacing.lg) {
                    Label(L10n.string("invite.code.header"), systemImage: "person.2.fill")
                        .font(SGFont.caption(11))
                        .tracking(1.3)
                        .foregroundStyle(SGT.ink3)

                    Text(L10n.string("invite.code.title"))
                        .font(SGFont.title(30))
                        .foregroundStyle(SGT.ink)

                    Text(L10n.string("invite.code.description"))
                        .font(SGFont.body(15))
                        .foregroundStyle(SGT.ink2)

                    TextField("AB12C-3DE45", text: $codeText)
                        .font(SGFont.numeric(24, weight: .semibold))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.continue)
                        .padding(.horizontal, SGSpacing.md)
                        .frame(minHeight: 58)
                        .background(SGT.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(errorMessage == nil ? SGT.rule : Color.red.opacity(0.65), lineWidth: 1)
                        }
                        .onSubmit { continueWithCode() }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .font(SGFont.caption(13))
                            .foregroundStyle(.red)
                    }

                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label(L10n.string("invite.code.paste"), systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SkySecondaryButtonStyle())

                    Button(L10n.string("invite.code.check"), action: continueWithCode)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(SkyPrimaryButtonStyle())
                        .disabled(codeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("inviteCodeRecovery.continue")
                }
                .padding(SGSpacing.xl)
            }
            .background(SGT.background)
            .navigationTitle(L10n.string("invite.code.navigationTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.close")) { dismiss() }
                }
            }
        }
        .sheet(item: $claimCode) { code in
            InviteClaimView(
                code: code,
                uid: uid,
                inviteRepository: inviteRepository,
                userRepository: userRepository,
                onFinished: {
                    claimCode = nil
                    dismiss()
                }
            )
        }
    }

    private func pasteFromClipboard() {
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else {
            errorMessage = L10n.string("invite.code.noPastedCode")
            return
        }
        codeText = pasted
        errorMessage = nil
    }

    private func continueWithCode() {
        let trimmed = codeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let code = InviteLinkParser.code(fromSharedText: trimmed) else {
            errorMessage = L10n.string("invite.code.invalidCode")
            return
        }
        errorMessage = nil
        claimCode = code
    }
}

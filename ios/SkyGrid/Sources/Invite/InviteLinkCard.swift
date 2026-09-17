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

    init(
        inviteRepository: any InviteRepository,
        placement: InviteAnalytics.Placement = .buddiesTab,
        onLinkReady: ((InviteLink) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: InviteLinkViewModel(
            inviteRepository: inviteRepository,
            placement: placement,
            onLinkReady: onLinkReady
        ))
        self.placement = placement
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            Text("INVITE A BUDDY")
                .font(SGFont.caption(11))
                .tracking(1.2)
                .foregroundStyle(SGT.accentSecondary)

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
                        .foregroundStyle(SGT.accent)
                        .frame(minHeight: 44)
                }
            case .failed(let message):
                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    Text(message)
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink2)
                    Button("Try again") { Task { await viewModel.load() } }
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
        .alert("Stop sharing this link?", isPresented: $showRevokeConfirmation) {
            Button("Stop sharing", role: .destructive) { Task { await viewModel.revoke() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Anyone who already has this code will no longer be able to use it.")
        }
    }

    @ViewBuilder
    private func readyContent(link: InviteLink) -> some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            Text("Group code")
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
                Text("Share link")
            }
            .font(SGFont.body(15))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(SGT.accent)
        .foregroundStyle(SGT.accentInk)
        .simultaneousGesture(TapGesture().onEnded {
            // ShareLink has no completion callback, only this tap — recorded on
            // the intent to share, not confirmed delivery.
            InviteAnalytics.record(.linkShared, placement: placement)
        })

        Button("Stop sharing this link", role: .destructive) {
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
                    Label("JOIN WITH A CODE", systemImage: "person.2.fill")
                        .font(SGFont.caption(11))
                        .tracking(1.3)
                        .foregroundStyle(SGT.ink3)

                    Text("Paste your buddy's invite code")
                        .font(SGFont.title(30))
                        .foregroundStyle(SGT.ink)

                    Text("If a link from Instagram or LINE did not open Sky Grid, enter the readable code from the message instead.")
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
                        Label("Paste from clipboard", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SkySecondaryButtonStyle())

                    Button("Check invite code", action: continueWithCode)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(SkyPrimaryButtonStyle())
                        .disabled(codeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("inviteCodeRecovery.continue")
                }
                .padding(SGSpacing.xl)
            }
            .background(SGT.background)
            .navigationTitle("Invite code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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
            errorMessage = "There is no invite code in the clipboard."
            return
        }
        codeText = pasted
        errorMessage = nil
    }

    private func continueWithCode() {
        let trimmed = codeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let code = InviteLinkParser.code(fromSharedText: trimmed) else {
            errorMessage = "Enter the 10-character code from the invite message."
            return
        }
        errorMessage = nil
        claimCode = code
    }
}

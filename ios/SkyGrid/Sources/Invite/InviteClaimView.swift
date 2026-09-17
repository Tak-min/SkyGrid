import SwiftUI

/// Presented as a sheet from `RootView` when a Universal Link or
/// `NSUserActivityTypeBrowsingWeb` continuation carries an invite code
/// (`AppRouter.pendingInviteCode`).
struct InviteClaimView: View {
    @State private var viewModel: InviteClaimViewModel
    @Environment(\.dismiss) private var dismiss
    let onFinished: () -> Void

    init(
        code: InviteCode,
        uid: String,
        inviteRepository: any InviteRepository,
        userRepository: any UserRepository,
        onFinished: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: InviteClaimViewModel(
            code: code,
            uid: uid,
            inviteRepository: inviteRepository,
            userRepository: userRepository
        ))
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            MokuColor.nightStage.ignoresSafeArea()

            VStack(spacing: SGSpacing.lg) {
                Spacer(minLength: SGSpacing.xl)

                switch viewModel.step {
                case .loadingPreview:
                    ProgressView()
                    Text(L10n.string("Checking your invite…"))
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink2)

                case .preview(let preview):
                    previewContent(preview)

                case .needsHandle:
                    HandleClaimView(uid: viewModel.uid, userRepository: viewModel.userRepository) { handle in
                        viewModel.handleClaimed(handle)
                    }
                    .padding(.horizontal, SGSpacing.md)

                case .claiming:
                    ProgressView()
                    Text(L10n.string("Connecting you…"))
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink2)

                case .result(let outcome):
                    resultContent(outcome)

                case .failed(let message):
                    terminal(
                        icon: "wifi.slash",
                        title: L10n.string("Something went wrong"),
                        message: message,
                        primaryTitle: L10n.string("Try again")
                    ) { Task { await viewModel.loadPreview() } }
                }

                Spacer(minLength: SGSpacing.xl)
            }
            .padding(SGSpacing.lg)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
        .task { await viewModel.loadPreview() }
    }

    @ViewBuilder
    private func previewContent(_ preview: InvitePreview) -> some View {
        switch preview.state {
        case .open:
            VStack(spacing: SGSpacing.md) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(SGT.accentSecondary)
                    .padding(.vertical, SGSpacing.sm)

                Text("Welcome!")
                    .font(SGFont.title(28))
                    .foregroundStyle(SGT.ink)

                Text(preview.creatorHandle.map { String(format: L10n.string("invite.claim.previewInvitedByHandle"), $0.value) } ?? L10n.string("invite.claim.previewInvitedGeneric"))
                    .font(SGFont.body(16))
                    .foregroundStyle(SGT.ink)
                    .multilineTextAlignment(.center)

                Text("Your skies stay softly blurred to each other until you've both captured the morning.")
                    .font(SGFont.body(14))
                    .foregroundStyle(SGT.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, SGSpacing.lg)

            Button {
                viewModel.beginClaim()
            } label: {
                Text("Join")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(SGT.accent)
            .foregroundStyle(SGT.accentInk)
            .frame(minHeight: 44)

            Button("Not now") { onFinished() }
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)

        case .claimedByYou:
            terminal(
                icon: "checkmark.circle.fill",
                title: L10n.string("Already connected"),
                message: preview.creatorHandle.map { String(format: L10n.string("invite.claim.alreadyBuddiesWithHandle"), $0.value) } ?? L10n.string("You’re already buddies."),
                primaryTitle: L10n.string("Done"),
                primaryAction: onFinished
            )
        case .ownInvite:
            terminal(
                icon: "link",
                title: L10n.string("This is your own link"),
                message: L10n.string("Share it with someone else to add them as a buddy."),
                primaryTitle: L10n.string("Done"),
                primaryAction: onFinished
            )
        case .expired:
            terminal(
                icon: "clock.badge.xmark",
                title: L10n.string("This link has expired"),
                message: L10n.string("Ask for a new invite link."),
                primaryTitle: L10n.string("Done"),
                primaryAction: onFinished
            )
        case .claimed:
            terminal(
                icon: "person.crop.circle.badge.xmark",
                title: L10n.string("This link has already been used"),
                message: L10n.string("Ask for a new invite link."),
                primaryTitle: L10n.string("Done"),
                primaryAction: onFinished
            )
        case .revoked:
            terminal(
                icon: "xmark.circle",
                title: L10n.string("This link isn't active"),
                message: L10n.string("Ask for a new invite link."),
                primaryTitle: L10n.string("Done"),
                primaryAction: onFinished
            )
        case .unknown:
            terminal(
                icon: "questionmark.circle",
                title: L10n.string("This link isn't valid"),
                message: L10n.string("Double-check the link, or ask for a new one."),
                primaryTitle: L10n.string("Done"),
                primaryAction: onFinished
            )
        }
    }

    @ViewBuilder
    private func resultContent(_ outcome: InviteClaimOutcome) -> some View {
        switch outcome {
        case .paired:
            terminal(
                icon: "checkmark.circle.fill",
                title: L10n.string("You're buddies now"),
                message: L10n.string("Capture your sky together, and you'll reveal each other's the moment you've each captured."),
                primaryTitle: L10n.string("Done"),
                primaryAction: onFinished
            )
        case .alreadyBuddies:
            terminal(
                icon: "checkmark.circle.fill",
                title: L10n.string("Already connected"),
                message: L10n.string("You're already buddies."),
                primaryTitle: L10n.string("Done"),
                primaryAction: onFinished
            )
        case .blocked:
            // Never names the other party — a block is only reversible from Settings
            // > Community & Safety, and this dead end must not hint at who or why.
            terminal(
                icon: "xmark.circle",
                title: L10n.string("This connection isn't available"),
                message: L10n.string("This link can't be used right now."),
                primaryTitle: L10n.string("Done"),
                primaryAction: onFinished
            )
        case .expired:
            terminal(icon: "clock.badge.xmark", title: L10n.string("This link has expired"), message: L10n.string("Ask for a new invite link."), primaryTitle: L10n.string("Done"), primaryAction: onFinished)
        case .revoked:
            terminal(icon: "xmark.circle", title: L10n.string("This link isn't active"), message: L10n.string("Ask for a new invite link."), primaryTitle: L10n.string("Done"), primaryAction: onFinished)
        case .claimed:
            terminal(icon: "person.crop.circle.badge.xmark", title: L10n.string("This link has already been used"), message: L10n.string("Ask for a new invite link."), primaryTitle: L10n.string("Done"), primaryAction: onFinished)
        case .ownInvite:
            terminal(icon: "link", title: L10n.string("This is your own link"), message: L10n.string("Share it with someone else to add them as a buddy."), primaryTitle: L10n.string("Done"), primaryAction: onFinished)
        case .circleFull:
            terminal(
                icon: "person.2.badge.minus",
                title: L10n.string("Your circle is full"),
                message: viewModel.canUpgradeCircle
                    ? L10n.string("invite.claim.circleFull.canUpgrade")
                    : L10n.string("invite.claim.circleFull.cannotUpgrade"),
                primaryTitle: L10n.string("Done"),
                primaryAction: onFinished
            )
        case .buddyCircleFull:
            terminal(
                icon: "person.2.badge.minus",
                title: L10n.string("This circle is full"),
                message: L10n.string("Ask them to make room—or, on Free, open Settings → Sky Grid Pro for an unlimited Circle—then try again."),
                primaryTitle: L10n.string("Done"),
                primaryAction: onFinished
            )
        case .unknown:
            terminal(icon: "questionmark.circle", title: L10n.string("This link isn't valid"), message: L10n.string("Double-check the link, or ask for a new one."), primaryTitle: L10n.string("Done"), primaryAction: onFinished)
        }
    }

    private func terminal(
        icon: String,
        title: String,
        message: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: SGSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(SGT.accentSecondary)
            Text(title)
                .font(SGFont.title(24))
                .foregroundStyle(SGT.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
                .multilineTextAlignment(.center)
            Button(primaryTitle, action: primaryAction)
                .buttonStyle(.borderedProminent)
                .tint(SGT.accent)
                .foregroundStyle(SGT.accentInk)
                .frame(minHeight: 44)
                .padding(.top, SGSpacing.xs)
        }
    }
}

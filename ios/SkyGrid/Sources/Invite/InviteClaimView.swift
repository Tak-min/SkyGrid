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
        VStack(spacing: SGSpacing.lg) {
            Spacer(minLength: SGSpacing.xl)

            switch viewModel.step {
            case .loadingPreview:
                ProgressView()
                Text("Checking your invite…")
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
                Text("Connecting you…")
                    .font(SGFont.body(16))
                    .foregroundStyle(SGT.ink2)

            case .result(let outcome):
                resultContent(outcome)

            case .failed(let message):
                terminal(
                    icon: "wifi.slash",
                    title: "Something went wrong",
                    message: message,
                    primaryTitle: "Try again"
                ) { Task { await viewModel.loadPreview() } }
            }

            Spacer(minLength: SGSpacing.xl)
        }
        .padding(SGSpacing.lg)
        .presentationDetents([.medium])
        .task { await viewModel.loadPreview() }
    }

    @ViewBuilder
    private func previewContent(_ preview: InvitePreview) -> some View {
        switch preview.state {
        case .open:
            VStack(spacing: SGSpacing.sm) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(SGT.ink)
                Text(preview.creatorHandle.map { "@\($0.value) invited you to Sky Grid" } ?? "You've been invited to Sky Grid")
                    .font(SGFont.serifTitle(24))
                    .foregroundStyle(SGT.ink)
                    .multilineTextAlignment(.center)
                Text("Your skies stay softly blurred to each other until you've both captured the morning.")
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
                    .multilineTextAlignment(.center)
            }
            Button("Become buddies") { viewModel.beginClaim() }
                .buttonStyle(.borderedProminent)
                // `SGT.ink` is a TEXT token and adapts: near-black in light, near-white in
                // dark. Using it as a prominent FILL therefore produced a white capsule
                // with `borderedProminent`'s automatic white label in dark mode. The
                // accent/accentInk pair is the app's primary-action fill and is fixed,
                // so it reads the same in both appearances.
                .tint(SGT.accent)
                .foregroundStyle(SGT.accentInk)
                .frame(minHeight: 44)
            Button("Not now") { onFinished() }
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)

        case .claimedByYou:
            terminal(
                icon: "checkmark.circle.fill",
                title: "Already connected",
                message: preview.creatorHandle.map { "You and @\($0.value) are already buddies." } ?? "You're already buddies.",
                primaryTitle: "Done",
                primaryAction: onFinished
            )
        case .ownInvite:
            terminal(
                icon: "link",
                title: "This is your own link",
                message: "Share it with someone else to add them as a buddy.",
                primaryTitle: "Done",
                primaryAction: onFinished
            )
        case .expired:
            terminal(
                icon: "clock.badge.xmark",
                title: "This link has expired",
                message: "Ask for a new invite link.",
                primaryTitle: "Done",
                primaryAction: onFinished
            )
        case .claimed:
            terminal(
                icon: "person.crop.circle.badge.xmark",
                title: "This link has already been used",
                message: "Ask for a new invite link.",
                primaryTitle: "Done",
                primaryAction: onFinished
            )
        case .revoked:
            terminal(
                icon: "xmark.circle",
                title: "This link isn't active",
                message: "Ask for a new invite link.",
                primaryTitle: "Done",
                primaryAction: onFinished
            )
        case .unknown:
            terminal(
                icon: "questionmark.circle",
                title: "This link isn't valid",
                message: "Double-check the link, or ask for a new one.",
                primaryTitle: "Done",
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
                title: "You're buddies now",
                message: "Capture your sky together, and you'll reveal each other's the moment you've each captured.",
                primaryTitle: "Done",
                primaryAction: onFinished
            )
        case .alreadyBuddies:
            terminal(
                icon: "checkmark.circle.fill",
                title: "Already connected",
                message: "You're already buddies.",
                primaryTitle: "Done",
                primaryAction: onFinished
            )
        case .blocked:
            // Never names the other party — a block is only reversible from Settings
            // > Community & Safety, and this dead end must not hint at who or why.
            terminal(
                icon: "xmark.circle",
                title: "This connection isn't available",
                message: "This link can't be used right now.",
                primaryTitle: "Done",
                primaryAction: onFinished
            )
        case .expired:
            terminal(icon: "clock.badge.xmark", title: "This link has expired", message: "Ask for a new invite link.", primaryTitle: "Done", primaryAction: onFinished)
        case .revoked:
            terminal(icon: "xmark.circle", title: "This link isn't active", message: "Ask for a new invite link.", primaryTitle: "Done", primaryAction: onFinished)
        case .claimed:
            terminal(icon: "person.crop.circle.badge.xmark", title: "This link has already been used", message: "Ask for a new invite link.", primaryTitle: "Done", primaryAction: onFinished)
        case .ownInvite:
            terminal(icon: "link", title: "This is your own link", message: "Share it with someone else to add them as a buddy.", primaryTitle: "Done", primaryAction: onFinished)
        case .circleFull:
            terminal(
                icon: "person.2.badge.minus",
                title: "Your circle is full",
                message: "Remove a buddy in Settings before joining someone new.",
                primaryTitle: "Done",
                primaryAction: onFinished
            )
        case .buddyCircleFull:
            terminal(
                icon: "person.2.badge.minus",
                title: "This circle is full",
                message: "Ask them to make room, then try this link again.",
                primaryTitle: "Done",
                primaryAction: onFinished
            )
        case .unknown:
            terminal(icon: "questionmark.circle", title: "This link isn't valid", message: "Double-check the link, or ask for a new one.", primaryTitle: "Done", primaryAction: onFinished)
        }
    }

    private func terminal(
        icon: String,
        title: String,
        message: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: SGSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(SGT.ink)
            Text(title)
                .font(SGFont.serifTitle(22))
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

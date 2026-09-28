import SwiftUI

/// The final onboarding step prepares a recoverable invite link and readable code.
/// It cannot be skipped forward, but the person can go back and edit earlier setup.
struct OnboardingInviteView: View {
    @State private var handle: Handle?
    @State private var hasUsableInvite = false

    let uid: String
    let userRepository: any UserRepository
    let inviteRepository: any InviteRepository
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                HStack {
                    Button(action: onBack) {
                        Label(L10n.string("Back"), systemImage: "chevron.left")
                            .frame(minHeight: 44)
                    }
                    .font(SGFont.caption(14))
                    .foregroundStyle(SGT.ink2)
                    Spacer()
                    Label(L10n.string("onboarding.invite.progressLabel"), systemImage: "person.2.fill")
                        .font(SGFont.caption(11))
                        .tracking(1.3)
                        .foregroundStyle(SGT.ink3)
                }

                OnboardingProgress(step: 11, total: OnboardingStep.allCases.count)

                VStack(alignment: .leading, spacing: SGSpacing.md) {
                    Label(L10n.string("MORNINGS TOGETHER"), systemImage: "person.2.fill")
                        .font(SGFont.caption(11))
                        .tracking(1.3)
                        .foregroundStyle(SGT.ink3)
                    Text(L10n.string("onboarding.invite.headline"))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(SGT.ink)
                    Text(L10n.string("Invite people you trust. You won't see each other's sky until you've both captured that morning."))
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink2)
                }

                if handle == nil {
                    HandleClaimView(uid: uid, userRepository: userRepository) { claimedHandle in
                        handle = claimedHandle
                        hasUsableInvite = false
                        Task { await BuddyPairingNotificationPermission.requestIfNeeded() }
                    }
                } else {
                    InviteLinkCard(
                        inviteRepository: inviteRepository,
                        placement: .onboarding,
                        onShareIntent: { hasUsableInvite = true }
                    )
                }

                Text(
                    hasUsableInvite ? L10n.string("onboarding.invite.ready")
                    : handle == nil ? L10n.string("onboarding.invite.waiting")
                    : L10n.string("onboarding.invite.needsShare")
                )
                    .font(SGFont.caption(13))
                    .foregroundStyle(SGT.ink2)

                Button(L10n.string("onboarding.invite.continueButton"), action: onContinue)
                    .font(SGFont.body(16))
                    .foregroundStyle(SGT.accentInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(SGT.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .disabled(handle == nil || !hasUsableInvite)
                    .opacity(handle == nil || !hasUsableInvite ? 0.45 : 1)
                    .accessibilityIdentifier("onboarding.continueWithInvite")
            }
            .padding(SGSpacing.xl)
            .padding(.bottom, SGSpacing.xl)
        }
        // A normally fresh onboarding account has no handle, but this also makes
        // a resumed onboarding honest: an already-claimed immutable handle goes
        // straight to the existing link instead of asking to replace it.
        .task {
            guard handle == nil else { return }
            for await observation in userRepository.observeProfile(uid: uid) {
                guard case .value(let profile?) = observation else { return }
                handle = profile.handle
                return
            }
        }
    }
}

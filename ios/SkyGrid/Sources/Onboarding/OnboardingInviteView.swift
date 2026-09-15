import SwiftUI

/// The final onboarding choice puts the mutual-reveal mechanic in front of every
/// new account without making social participation a condition of using Sky Grid.
/// A handle is only collected after the person chooses to invite, matching the
/// existing Buddies-tab privacy boundary and the server's `createInvite` contract.
struct OnboardingInviteView: View {
    @State private var handle: Handle?

    let uid: String
    let userRepository: any UserRepository
    let inviteRepository: any InviteRepository
    let onSkip: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                HStack {
                    Spacer()
                    Button("Not now", action: onSkip)
                        .font(SGFont.caption(14))
                        .foregroundStyle(SGT.ink2)
                        .frame(minHeight: 44)
                }

                OnboardingProgress(step: 10, total: 10)

                VStack(alignment: .leading, spacing: SGSpacing.md) {
                    Label("MORNINGS TOGETHER", systemImage: "person.2.fill")
                        .font(SGFont.caption(11))
                        .tracking(1.3)
                        .foregroundStyle(SGT.ink3)
                    Text("Reveal your skies\ntogether.")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(SGT.ink)
                    Text("Invite people you trust. Each sky stays sealed until you've each captured the same morning.")
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink2)
                }

                if handle == nil {
                    HandleClaimView(uid: uid, userRepository: userRepository) { claimedHandle in
                        handle = claimedHandle
                    }
                } else {
                    InviteLinkCard(inviteRepository: inviteRepository, placement: .onboarding)
                }

                Button(handle == nil ? "Skip for now" : "Start Sky Grid", action: onSkip)
                    .font(SGFont.body(16))
                    .foregroundStyle(SGT.ink2)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
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

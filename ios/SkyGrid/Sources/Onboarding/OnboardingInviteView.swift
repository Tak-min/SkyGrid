import SwiftUI

/// The final onboarding choice puts the mutual-reveal mechanic in front of every
/// new account without making social participation a condition of using Sky Grid.
/// A handle is only collected after the person chooses to invite, matching the
/// existing Buddies-tab privacy boundary and the server's `createInvite` contract.
struct OnboardingInviteView: View {
    @State private var handle: Handle?
    @State private var referralCode: String = ""

    let uid: String
    let userRepository: any UserRepository
    let inviteRepository: any InviteRepository
    let onSkip: () -> Void

    /// Records a non-empty referral code (fire-and-forget, no validation — this is
    /// an attribution hint, not a gate) before handing off to `onSkip`. Both exit
    /// points on this screen ("Not now" and the primary button) funnel through
    /// here so whatever was typed is captured regardless of which one is tapped.
    private func finishOnboarding() {
        let trimmedCode = referralCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCode.isEmpty {
            Task {
                try? await userRepository.setReferralCode(trimmedCode, for: uid)
            }
        }
        onSkip()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                HStack {
                    Spacer()
                    Button("Not now", action: finishOnboarding)
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

                // Optional, unvalidated attribution hint — kept low-emphasis so it
                // never competes with the invite mechanic above for attention.
                TextField("Referral code (optional)", text: $referralCode)
                    .font(SGFont.caption(13))
                    .foregroundStyle(SGT.ink2)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, SGSpacing.md)
                    .frame(minHeight: 36)
                    .background(SGT.ghostFaint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button(handle == nil ? "Skip for now" : "Start Sky Grid", action: finishOnboarding)
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

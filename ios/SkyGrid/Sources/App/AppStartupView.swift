import SwiftUI
import AuthenticationServices

struct AppStartupView: View {
    @Bindable var startup: AppStartupController
    let appRouter: AppRouter

    var body: some View {
        Group {
            switch startup.state {
            case .idle, .loading:
                VStack(spacing: 14) {
                    RitualGridMark(side: 42)
                    ProgressView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SGT.background)
            case .authenticationRequired:
                AccountAccessView(
                    errorMessage: startup.authenticationError,
                    onAppleAuthorization: { credential, rawNonce in
                        Task { await startup.signInWithApple(credential: credential, rawNonce: rawNonce) }
                    },
                    onAppleAuthorizationFailure: startup.appleAuthorizationFailed,
                    onContinueAsGuest: { Task { await startup.startNewAnonymousSession() } }
                )
                // Debug-only: skip the tap on "Start without an account" so the
                // second-chance paywall screenshot fixture (RootView) can be
                // reached without any UI automation. Same launch-arg convention as
                // `-SkyGridSkipOnboarding`/`-SkyGridLaunchGrid`.
                .task {
                    guard RootView.isSecondChanceScreenshotFixture else { return }
                    await startup.startNewAnonymousSession()
                }
            case .ready(let services):
                RootView(onAccountDeleted: {
                    Task { await startup.restartAfterAccountDeletion() }
                })
                .environment(\.appServices, services)
                .environment(appRouter)
            case .deleted:
                AccountDeletedView {
                    Task { await startup.startNewAnonymousSession() }
                }
            case .failed(let error):
                // Every string here comes from `StartupFailureMessage`, never from
                // `error.localizedDescription` — see that type for why.
                let message = StartupFailureMessage.make(for: error)
                ContentUnavailableView {
                    Label(message.title, systemImage: "cloud.slash")
                } description: {
                    Text(message.recovery)
                } actions: {
                    Button("Try again") {
                        Task { await startup.startNewAnonymousSession() }
                    }
                    .buttonStyle(SkyPrimaryButtonStyle())
                }
                .padding(24)
                .background(SGT.background)
            }
        }
        .task {
            if case .idle = startup.state {
                await startup.start()
            }
        }
    }
}

/// Apple creates a durable Firebase identity. A temporary account remains
/// available for a low-friction first photo, but it can later be linked from
/// Settings without changing its Firebase UID or splitting its archive.
private struct AccountAccessView: View {
    @Environment(\.colorScheme) private var colorScheme
    let errorMessage: String?
    let onAppleAuthorization: (ASAuthorizationAppleIDCredential, String) -> Void
    let onAppleAuthorizationFailure: (Error) -> Void
    let onContinueAsGuest: () -> Void
    @State private var pendingAppleNonce: String?

    var body: some View {
        VStack(spacing: SGSpacing.xl) {
            Spacer()
            RitualGridMark(side: 56)
            VStack(spacing: SGSpacing.sm) {
                Text("KEEP YOUR SKY GRID")
                    .font(SGFont.caption(12))
                    .tracking(1.6)
                    .foregroundStyle(SGT.ink3)
                Text("Your mornings,\nkept together.")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SGT.ink)
                Text("Sign in with Apple to restore your archive whenever you return to Sky Grid.")
                    .font(SGFont.body(15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SGT.ink2)
            }

            VStack(spacing: SGSpacing.md) {
                SignInWithAppleButton(.signIn) { request in
                    let nonce = AppleSignInNonce.make()
                    pendingAppleNonce = nonce
                    request.requestedScopes = [.email]
                    request.nonce = AppleSignInNonce.sha256(nonce)
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                              let nonce = pendingAppleNonce
                        else {
                            onAppleAuthorizationFailure(AppleAccountLinkError.invalidCredential)
                            return
                        }
                        pendingAppleNonce = nil
                        onAppleAuthorization(credential, nonce)
                    case .failure(let error):
                        pendingAppleNonce = nil
                        onAppleAuthorizationFailure(error)
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Start without an account", action: onContinueAsGuest)
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
                    .frame(minHeight: 44)

                Text("You can connect Apple later in Settings. Your photos are never merged into another account automatically.")
                    .font(SGFont.caption(12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SGT.ink3)
            }
            .padding(.top, SGSpacing.md)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(SGFont.caption(13))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, SGSpacing.sm)
            }
            Spacer()
        }
        .padding(SGSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGT.background)
    }
}

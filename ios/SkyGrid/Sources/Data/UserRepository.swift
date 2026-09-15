import Foundation

/// A missing profile is a valid server value; a listener failure is not. Keeping
/// those outcomes separate prevents invite and safety screens from treating an
/// offline read as a profile that has no handle or display name.
enum UserProfileObservation: Sendable {
    case value(UserProfile?)
    case unavailable
}

@MainActor
protocol UserRepository: Sendable {
    func observeProfile(uid: String) -> AsyncStream<UserProfileObservation>
    func createOrUpdateProfile(_ profile: UserProfile) async throws

    /// Attempts to atomically claim `handle` for `uid` via `handles/{handle}`.
    /// Throws `.handleAlreadyTaken` if it's in use. Handles cannot be changed once
    /// claimed (blueprint §2-G) — this is the only handle-write entry point.
    func claimHandle(_ handle: Handle, for uid: String) async throws

    func findUid(forHandle handle: Handle) async throws -> String?

    /// Records which creator/ambassador (if any) a new user came from. Free-text,
    /// unvalidated — this is an attribution hint, not an identity boundary, so it
    /// merges into the existing profile document rather than gating anything.
    func setReferralCode(_ code: String, for uid: String) async throws
}

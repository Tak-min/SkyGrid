import Foundation

@MainActor
protocol UserRepository: Sendable {
    func observeProfile(uid: String) -> AsyncStream<UserProfile?>
    func createOrUpdateProfile(_ profile: UserProfile) async throws

    /// Attempts to atomically claim `handle` for `uid` via `handles/{handle}`.
    /// Throws `.handleAlreadyTaken` if it's in use. Handles cannot be changed once
    /// claimed (blueprint §2-G) — this is the only handle-write entry point.
    func claimHandle(_ handle: Handle, for uid: String) async throws

    func findUid(forHandle handle: Handle) async throws -> String?
}

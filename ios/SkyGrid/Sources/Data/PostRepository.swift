import Foundation

/// Abstracts over the Local (Phase 1, JSON-backed) and Firestore (Phase 2) post
/// backends. Views/ViewModels depend only on this protocol — `ServiceFactory` is the
/// single place that decides which concrete implementation to inject (blueprint §6).
/// `@MainActor`-isolated: every current and planned conformer (Local, Firestore) is
/// driven by MainActor-bound ViewModels anyway, so isolating the protocol itself
/// avoids a latent Swift 6 strict-concurrency conformance error.
@MainActor
protocol PostRepository: Sendable {
    /// Live updates for one user's post on one day (nil once seen as absent).
    func observePost(uid: String, localDate: LocalDate) -> AsyncStream<SkyPost?>

    /// Live updates for a user's posts across a date range (used by `SkyGridViewModel`).
    func observePosts(uid: String, from: LocalDate, through: LocalDate) -> AsyncStream<[SkyPost]>

    /// Writes the post document. Must be safe to call at most once per
    /// `(uid, localDate)` — the backend enforces "one post per day" via `create`-only
    /// semantics (Firestore Rules) or an equivalent Local-backend check.
    func createPost(_ draft: PostDraft) async throws

    func deletePost(uid: String, localDate: LocalDate) async throws
}

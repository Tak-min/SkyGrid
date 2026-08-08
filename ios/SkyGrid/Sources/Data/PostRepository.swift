import Foundation

/// A failed post read is not proof that the day is empty. Keeping that state
/// separate prevents a Firebase/App Check failure from opening the camera and
/// producing a contradictory write failure immediately afterwards.
enum PostObservation: Sendable {
    case value(SkyPost?)
    case unavailable
}

/// A failed collection read is not an empty archive. Consumers keep their last
/// confirmed value and show a retryable unavailable state until Firestore recovers.
enum PostCollectionObservation: Sendable {
    case value([SkyPost])
    case unavailable
}

/// Abstracts over the Local (Phase 1, JSON-backed) and Firestore (Phase 2) post
/// backends. Views/ViewModels depend only on this protocol — `ServiceFactory` is the
/// single place that decides which concrete implementation to inject (blueprint §6).
/// `@MainActor`-isolated: every current and planned conformer (Local, Firestore) is
/// driven by MainActor-bound ViewModels anyway, so isolating the protocol itself
/// avoids a latent Swift 6 strict-concurrency conformance error.
@MainActor
protocol PostRepository: Sendable {
    /// Live updates for one user's post on one day.
    func observePost(uid: String, localDate: LocalDate) -> AsyncStream<PostObservation>

    /// Live updates for a user's posts across a date range (used by `SkyGridViewModel`).
    func observePosts(uid: String, from: LocalDate, through: LocalDate) -> AsyncStream<PostCollectionObservation>

    /// Reads one post directly from the backend, bypassing cache when the concrete
    /// implementation supports it. The durable outbox uses this only after a
    /// create-only write reports a duplicate, to distinguish its own acknowledged
    /// post from another capture that owns the same day.
    func fetchPost(uid: String, localDate: LocalDate) async throws -> SkyPost?

    /// Writes the post document. Must be safe to call at most once per
    /// `(uid, localDate)` — the backend enforces "one post per day" via `create`-only
    /// semantics (Firestore Rules) or an equivalent Local-backend check.
    func createPost(_ draft: PostDraft) async throws

    func deletePost(uid: String, localDate: LocalDate) async throws
}

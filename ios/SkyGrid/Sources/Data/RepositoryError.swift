import Foundation

/// Cross-layer error type. Firebase-specific errors are folded into this at the
/// `Data/Firestore/` boundary so nothing above `Data/` ever imports FirebaseFirestore.
enum RepositoryError: Error, Sendable {
    case notFound
    case notAuthenticated
    case handleAlreadyTaken
    case alreadyPostedToday
    case network(underlying: String)
    case unknown(underlying: String)
}

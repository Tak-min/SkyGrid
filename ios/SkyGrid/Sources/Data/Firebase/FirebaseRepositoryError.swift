import Foundation

enum FirebaseRepositoryError {
    static func map(_ error: Error) -> RepositoryError {
        if let repositoryError = error as? RepositoryError {
            return repositoryError
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .network(underlying: nsError.localizedDescription)
        }
        return .unknown(underlying: nsError.localizedDescription)
    }
}

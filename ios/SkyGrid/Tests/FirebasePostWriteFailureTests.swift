import Foundation
import Testing
@testable import SkyGrid

@Suite("Firebase post write failure classification")
struct FirebasePostWriteFailureTests {
    @Test("a Firestore permission denial is not itself proof of a duplicate")
    func permissionDeniedNeedsServerConfirmation() {
        let error = NSError(
            domain: "FIRFirestoreErrorDomain",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Missing or insufficient permissions."]
        )

        #expect(FirebasePostWriteFailure.isPermissionDenied(error))
        #expect(!FirebasePostWriteFailure.isExplicitDuplicate(error))
    }

    @Test("an explicit already-exists response remains a duplicate")
    func explicitAlreadyExistsIsDuplicate() {
        let error = NSError(
            domain: "FIRFirestoreErrorDomain",
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Document already exists."]
        )

        #expect(FirebasePostWriteFailure.isExplicitDuplicate(error))
    }

    @Test("an unrelated error code six is not treated as a Firestore duplicate")
    func unrelatedCodeSixIsNotDuplicate() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "The operation could not be completed."]
        )

        #expect(!FirebasePostWriteFailure.isExplicitDuplicate(error))
    }
}

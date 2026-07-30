@preconcurrency import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseContentSafetyRepository: ContentSafetyRepository {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func submitConcern(reporterUid: String, subjectUid: String) async throws {
        let report = ContentReport(
            id: UUID(),
            reporterUid: reporterUid,
            subjectUid: subjectUid,
            createdAt: Date(),
            status: .received
        )
        do {
            try await firestore.collection("reports").document(report.id.uuidString).setDataAsync([
                "reporterUid": report.reporterUid,
                "subjectUid": report.subjectUid,
                "createdAt": FieldValue.serverTimestamp(),
                "status": report.status.rawValue,
            ])
        } catch {
            throw FirebaseRepositoryError.map(error)
        }
    }
}

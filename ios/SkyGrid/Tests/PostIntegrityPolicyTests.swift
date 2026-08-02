import Testing
import Foundation
@testable import SkyGrid

@Suite("PostIntegrityPolicy")
struct PostIntegrityPolicyTests {
    private let postImagePath = "posts/uid/2026-08-02/image.jpg"
    private let pastGrace: TimeInterval = 200

    private func row(
        state: UploadState,
        path: String? = nil,
        hasLocalFullImage: Bool = true
    ) -> PostIntegrityPolicy.QueueRow {
        PostIntegrityPolicy.QueueRow(
            state: state,
            fullImagePath: path ?? postImagePath,
            hasLocalFullImage: hasLocalFullImage
        )
    }

    @Test("full image present is intact regardless of everything else")
    func fullImagePresentIsIntact() {
        let result = PostIntegrityPolicy.evaluate(
            fullImage: .present,
            thumbImage: .absent,
            row: nil,
            postImagePath: postImagePath,
            postAge: pastGrace
        )
        #expect(result == .intact)
    }

    @Test("thumb image present is intact even if the full image is absent")
    func thumbImagePresentIsIntact() {
        let result = PostIntegrityPolicy.evaluate(
            fullImage: .absent,
            thumbImage: .present,
            row: nil,
            postImagePath: postImagePath,
            postAge: pastGrace
        )
        #expect(result == .intact)
    }

    @Test("an indeterminate full-image read is never treated as proof of absence")
    func indeterminateFullImageIsUndetermined() {
        let result = PostIntegrityPolicy.evaluate(
            fullImage: .indeterminate,
            thumbImage: .absent,
            row: nil,
            postImagePath: postImagePath,
            postAge: pastGrace
        )
        #expect(result == .undetermined)
    }

    @Test("an indeterminate thumb-image read is never treated as proof of absence")
    func indeterminateThumbImageIsUndetermined() {
        let result = PostIntegrityPolicy.evaluate(
            fullImage: .absent,
            thumbImage: .indeterminate,
            row: nil,
            postImagePath: postImagePath,
            postAge: pastGrace
        )
        #expect(result == .undetermined)
    }

    @Test("both absent but still inside the grace window is undetermined, not orphaned")
    func withinGraceWindowIsUndetermined() {
        let result = PostIntegrityPolicy.evaluate(
            fullImage: .absent,
            thumbImage: .absent,
            row: nil,
            postImagePath: postImagePath,
            postAge: 5,
            graceInterval: 120
        )
        #expect(result == .undetermined)
    }

    @Test("no queue row at all, past grace, is orphaned")
    func noRowPastGraceIsOrphaned() {
        let result = PostIntegrityPolicy.evaluate(
            fullImage: .absent,
            thumbImage: .absent,
            row: nil,
            postImagePath: postImagePath,
            postAge: pastGrace
        )
        #expect(result == .orphaned)
    }

    @Test("a row belonging to a different capture is orphaned")
    func mismatchedRowIsOrphaned() {
        let result = PostIntegrityPolicy.evaluate(
            fullImage: .absent,
            thumbImage: .absent,
            row: row(state: .pendingLocal, path: "posts/uid/2026-08-02/different.jpg"),
            postImagePath: postImagePath,
            postAge: pastGrace
        )
        #expect(result == .orphaned)
    }

    @Test("a matching row still pendingLocal is uploadPending")
    func matchingPendingLocalRowIsUploadPending() {
        let result = PostIntegrityPolicy.evaluate(
            fullImage: .absent,
            thumbImage: .absent,
            row: row(state: .pendingLocal),
            postImagePath: postImagePath,
            postAge: pastGrace
        )
        #expect(result == .uploadPending)
    }

    @Test("a matching row currently uploading is uploadPending")
    func matchingUploadingRowIsUploadPending() {
        let result = PostIntegrityPolicy.evaluate(
            fullImage: .absent,
            thumbImage: .absent,
            row: row(state: .uploading),
            postImagePath: postImagePath,
            postAge: pastGrace
        )
        #expect(result == .uploadPending)
    }

    @Test("a failed row that still has the local file is uploadPending, not orphaned")
    func failedRowWithLocalFileIsUploadPending() {
        let result = PostIntegrityPolicy.evaluate(
            fullImage: .absent,
            thumbImage: .absent,
            row: row(state: .failed, hasLocalFullImage: true),
            postImagePath: postImagePath,
            postAge: pastGrace
        )
        #expect(result == .uploadPending, "Retry now should be offered while the bytes are still recoverable")
    }

    @Test("a failed row with no recoverable local file is orphaned")
    func failedRowWithoutLocalFileIsOrphaned() {
        let result = PostIntegrityPolicy.evaluate(
            fullImage: .absent,
            thumbImage: .absent,
            row: row(state: .failed, hasLocalFullImage: false),
            postImagePath: postImagePath,
            postAge: pastGrace
        )
        #expect(result == .orphaned)
    }

    @Test("a row claiming done while Storage reports absent is undetermined, never auto-acted-on")
    func contradictoryDoneRowIsUndetermined() {
        let result = PostIntegrityPolicy.evaluate(
            fullImage: .absent,
            thumbImage: .absent,
            row: row(state: .done),
            postImagePath: postImagePath,
            postAge: pastGrace
        )
        #expect(result == .undetermined)
    }
}

import Testing
@testable import SkyGrid

/// `PendingCellState.init(uploadState:)` is the mapping that decides which Grid
/// cells are allowed to look "occupied but unconfirmed" versus which collapse into
/// which of the 3 honest states — see `PendingCellState`'s own doc comment for why
/// there is deliberately no 4th "looks confirmed" case. Every `UploadState` case is
/// asserted explicitly so a future case added to `UploadState` without updating this
/// mapping fails to compile (no `default:` in the source switch) rather than
/// silently mapping to the wrong bucket.
@Suite("PendingCellState")
struct PendingCellStateTests {
    @Test(
        "in-flight upload states collapse to .inFlight",
        arguments: [UploadState.stagedPost, .pendingLocal, .uploading, .done]
    )
    func inFlightStatesMapToInFlight(uploadState: UploadState) {
        #expect(PendingCellState(uploadState: uploadState) == .inFlight)
    }

    @Test(
        "rejected/failed upload states collapse to .retryableFailure",
        arguments: [UploadState.failed, .postFailed]
    )
    func failedStatesMapToRetryableFailure(uploadState: UploadState) {
        #expect(PendingCellState(uploadState: uploadState) == .retryableFailure)
    }

    @Test("a conflicting document maps to .needsReview")
    func conflictStateMapsToNeedsReview() {
        #expect(PendingCellState(uploadState: .postConflict) == .needsReview)
    }
}

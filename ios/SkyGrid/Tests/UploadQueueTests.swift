import Testing
import Foundation
@testable import SkyGrid

@Suite("UploadQueue")
struct UploadQueueTests {
    private struct SucceedingImageUploader: ImageUploading {
        func upload(fileURL: URL, to path: String, contentType: String) async throws {}
    }

    private struct AlwaysFailingImageUploader: ImageUploading {
        struct UploadFailed: Error {}

        func upload(fileURL: URL, to path: String, contentType: String) async throws {
            throw UploadFailed()
        }
    }

    private func makeDraft(dateOffset: Int = 0) -> PostDraft {
        let date = LocalDate(year: 2026, month: 7, day: 29).adding(days: dateOffset)
        return PostDraft(
            ownerUid: "test-uid",
            localDate: date,
            capturedAt: Date(),
            skyColor: SkyColor(uncheckedHex: "#7EA3C8"),
            minutesFromGoal: 5,
            imageID: UUID(),
            localFullImageURL: URL(fileURLWithPath: "/tmp/skygrid-test-full.jpg"),
            localThumbImageURL: URL(fileURLWithPath: "/tmp/skygrid-test-thumb.jpg")
        )
    }

    @Test("enqueue then drain transitions a pending upload to done")
    func enqueueThenDrainSucceeds() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: SucceedingImageUploader())
        try await queue.enqueue(makeDraft())

        // kick() spawns a detached drain task inside the actor; give it a moment.
        try await Task.sleep(nanoseconds: 300_000_000)

        let summary = try await queue.pendingSummary()
        #expect(summary.count == 1)
        #expect(summary.first?.state == .done)
    }

    @Test("a failing uploader retries with an incremented attempt count, never silently drops the record")
    func failingUploadRetriesWithoutDropping() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: AlwaysFailingImageUploader())
        try await queue.enqueue(makeDraft())

        try await Task.sleep(nanoseconds: 300_000_000)

        let summary = try await queue.pendingSummary()
        #expect(summary.count == 1)
        #expect(summary.first?.state == .pendingLocal)
        #expect((summary.first?.attemptCount ?? 0) >= 1)
        #expect(summary.first?.lastError != nil)
    }

    @Test("upload queue uniqueness is scoped to account and local day")
    func differentAccountsCanQueueTheSameDay() async throws {
        let container = LocalStoreContainer.make(inMemory: true)
        let queue = UploadQueue(modelContainer: container, uploader: AlwaysFailingImageUploader())
        let first = makeDraft()
        let second = PostDraft(
            ownerUid: "another-account",
            localDate: first.localDate,
            capturedAt: first.capturedAt,
            skyColor: first.skyColor,
            minutesFromGoal: first.minutesFromGoal,
            imageID: UUID(),
            localFullImageURL: first.localFullImageURL,
            localThumbImageURL: first.localThumbImageURL
        )

        try await queue.enqueue(first)
        try await queue.enqueue(second)
        try await Task.sleep(nanoseconds: 300_000_000)

        let summary = try await queue.pendingSummary()
        #expect(summary.count == 2)
        #expect(Set(summary.map(\.queueID)).count == 2)
    }
}

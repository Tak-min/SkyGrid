import Foundation
import Testing
@testable import SkyGrid

@Suite("FirstUnlockPaywallPolicy")
struct FirstUnlockPaywallPolicyTests {
    private let today = LocalDate(year: 2025, month: 1, day: 10)

    private func reading(count: Int, acceptedBuddyCount: Int? = 1) -> RevealReading {
        RevealReading(localDate: today, mutuallyUnlockedBuddyCount: count, acceptedBuddyCount: acceptedBuddyCount)
    }

    @Test("does not present without a mutual unlock")
    func requiresMutualUnlock() {
        #expect(!FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            reading: nil,
            completedCaptureCount: 5,
            hasPresentedUnlockPaywall: false
        ))
        #expect(!FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            reading: reading(count: 0),
            completedCaptureCount: 5,
            hasPresentedUnlockPaywall: false
        ))
    }

    @Test("presents the moment a buddy is mutually unlocked, at the very first capture")
    func presentsAtFirstCapture() {
        #expect(FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            reading: reading(count: 1),
            completedCaptureCount: 1,
            hasPresentedUnlockPaywall: false
        ))
    }

    @Test("does not interrupt subscribers but lets unresolved access reach verification")
    func separatesSubscriberFromUnresolvedAccess() {
        #expect(!FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .subscribed,
            reading: reading(count: 1),
            completedCaptureCount: 1,
            hasPresentedUnlockPaywall: false
        ))
        #expect(FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .unknown,
            reading: reading(count: 1),
            completedCaptureCount: 1,
            hasPresentedUnlockPaywall: false
        ))
    }

    @Test("never presents a second time, regardless of how many buddies unlock later")
    func isOneShot() {
        #expect(!FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            reading: reading(count: 3),
            completedCaptureCount: 40,
            hasPresentedUnlockPaywall: true
        ))
    }

    @Test("ignores acceptedBuddyCount entirely — a nil (unresolved) value must not block a real mutual unlock")
    func doesNotReadAcceptedBuddyCount() {
        #expect(FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: .notSubscribed,
            reading: reading(count: 1, acceptedBuddyCount: nil),
            completedCaptureCount: 1,
            hasPresentedUnlockPaywall: false
        ))
    }
}

@Suite("TodayViewModel buddy refresh")
@MainActor
struct TodayViewModelBuddyRefreshTests {
    private let today = LocalDate(year: 2026, month: 9, day: 5)
    private let viewerUID = "viewer"

    private struct NoopImageUploader: ImageUploading { func upload(fileURL: URL, to path: String, contentType: String) async throws {} }
    private struct NoopOrphanedRecovery: OrphanedPostRecovering {
        func evaluate(post: SkyPost, now: Date) async -> TodayPostIntegrity { .intact }
        func recover(post: SkyPost) async throws {}
    }

    private final class Posts: PostRepository {
        var values: [String: SkyPost?]
        init(_ values: [String: SkyPost?]) { self.values = values }
        func observePost(uid: String, localDate: LocalDate) -> AsyncStream<PostObservation> {
            let post = values[uid] ?? nil
            return AsyncStream { $0.yield(.value(post)); $0.finish() }
        }
        func observePosts(uid: String, from: LocalDate, through: LocalDate) -> AsyncStream<PostCollectionObservation> {
            AsyncStream { $0.yield(.value([])); $0.finish() }
        }
        func fetchPost(uid: String, localDate: LocalDate) async throws -> SkyPost? { values[uid] ?? nil }
        func createPost(_ draft: PostDraft) async throws {}
        func deletePost(uid: String, localDate: LocalDate) async throws {}
    }

    private final class Profiles: UserRepository {
        func observeProfile(uid: String) -> AsyncStream<UserProfileObservation> {
            AsyncStream {
                $0.yield(.value(UserProfile(uid: uid, handle: Handle(raw: "buddy_\(uid)"), displayName: uid, timezone: "UTC", wakeGoalMinutes: 360, streakCurrent: 0, streakLongest: 0, lastPostLocalDate: nil, isPro: false)))
                $0.finish()
            }
        }
        func createOrUpdateProfile(_ profile: UserProfile) async throws {}
        func claimHandle(_ handle: Handle, for uid: String) async throws {}
        func findUid(forHandle handle: Handle) async throws -> String? { nil }
    }

    private final class Friends: FriendRepository {
        let values: [Friendship]
        init(_ values: [Friendship]) { self.values = values }
        func observeFriendships(uid: String) -> AsyncStream<FriendshipCollectionObservation> { AsyncStream { $0.yield(.value(values)); $0.finish() } }
        func observeBlockedFriendships(uid: String) -> AsyncStream<BlockedFriendshipCollectionObservation> { AsyncStream { $0.yield(.value([])); $0.finish() } }
        func sendRequest(from: String, to: String, requesterHandle: Handle, recipientHandle: Handle) async throws -> FriendRequestResult { .sent }
        func acceptRequest(pairId: String, acceptingUid: String) async throws -> FriendRequestAcceptanceResult { .accepted }
        func removeFriendship(pairId: String) async throws {}
        func block(ownerUid: String, blockedUid: String) async throws {}
        func unblock(ownerUid: String, blockedUid: String) async throws {}
        func isBlocked(ownerUid: String, otherUid: String) async throws -> Bool { false }
    }

    private func post(_ uid: String) -> SkyPost {
        SkyPost(ownerUid: uid, localDate: today, capturedAt: Date(timeIntervalSince1970: 1_788_566_400), uploadedAt: Date(timeIntervalSince1970: 1_788_566_460), imagePath: "posts/\(uid)/image.jpg", thumbPath: "posts/\(uid)/thumb.jpg", skyColor: SkyColor(uncheckedHex: "#7EA3C8"), minutesFromGoal: 0, reactions: [:])
    }

    private func circle() -> [Friendship] {
        (1...8).map { index in
            let buddy = "buddy\(index)"
            return Friendship(pairId: PairID.make(viewerUID, buddy), members: [viewerUID, buddy], status: .accepted, requestedBy: viewerUID, createdAt: .distantPast, blockedBy: [])
        }
    }

    private func makeViewModel(posts: Posts, signal: RevealSignal) -> TodayViewModel {
        TodayViewModel(uid: viewerUID, postRepository: posts, userRepository: Profiles(), friendRepository: Friends(circle()), uploadQueue: UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: NoopImageUploader()), orphanedPostRecovery: NoopOrphanedRecovery(), clock: FixedClock(now: Date(timeIntervalSince1970: 1_788_566_400)), revealSignal: signal)
    }

    private func awaitReading(_ signal: RevealSignal, where predicate: (RevealReading) -> Bool) async {
        let deadline = Date().addingTimeInterval(5)
        while !(signal.reading.map(predicate) ?? false), Date() < deadline { await Task.yield() }
    }

    @Test("the cap-sized circle is fully read and republished for the Buddies tab")
    func refreshesAllCapMembersAndRepublishesEveryStatus() async {
        let posts = Posts([viewerUID: post(viewerUID), "buddy8": post("buddy8")])
        let signal = RevealSignal()
        let viewModel = makeViewModel(posts: posts, signal: signal)
        viewModel.start(for: today)
        await awaitReading(signal) { $0.buddyStatuses.count == 8 }

        #expect(signal.reading?.acceptedBuddyCount == 8)
        #expect(signal.reading?.buddyStatuses.count == 8)
        #expect(signal.reading?.buddyStatuses.first(where: { $0.uid == "buddy8" })?.revealState == .posted(post("buddy8")))
        #expect(signal.reading?.buddyStatuses.first(where: { $0.uid == "buddy7" })?.revealState == .notYet)
        #expect(signal.reading?.mutuallyUnlockedBuddyCount == 1)
        #expect(BuddyRow.displayLimit > 8)
        viewModel.stop()
    }

    @Test("an unrevealed cap-sized circle remains sealed rather than claiming not yet")
    func preservesSealedStateBeforeViewerPosts() async {
        let signal = RevealSignal()
        let viewModel = makeViewModel(posts: Posts([:]), signal: signal)
        viewModel.start(for: today)
        await awaitReading(signal) { $0.buddyStatuses.count == 8 }

        #expect(signal.reading?.buddyStatuses.count == 8)
        #expect(signal.reading?.buddyStatuses.allSatisfy { $0.revealState == .sealed } == true)
        #expect(signal.reading?.mutuallyUnlockedBuddyCount == 0)
        viewModel.stop()
    }

    @Test("a late post from the final cap member remains a mutual unlock")
    func refreshesPostFromFinalCapMember() async {
        let posts = Posts([viewerUID: post(viewerUID)])
        let signal = RevealSignal()
        let viewModel = makeViewModel(posts: posts, signal: signal)
        viewModel.start(for: today)
        await awaitReading(signal) { $0.buddyStatuses.count == 8 && $0.mutuallyUnlockedBuddyCount == 0 }

        posts.values["buddy8"] = post("buddy8")
        viewModel.refreshBuddiesNow()
        await awaitReading(signal) { $0.mutuallyUnlockedBuddyCount == 1 }
        #expect(signal.reading?.buddyStatuses.count == 8)
        #expect(signal.reading?.buddyStatuses.first(where: { $0.uid == "buddy8" })?.revealState == .posted(post("buddy8")))
        viewModel.stop()
    }
}

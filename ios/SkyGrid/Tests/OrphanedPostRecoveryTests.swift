import Testing
import Foundation
@testable import SkyGrid

@Suite("OrphanedPostRecovery")
@MainActor
struct OrphanedPostRecoveryTests {
    private struct SucceedingImageUploader: ImageUploading {
        func upload(fileURL: URL, to path: String, contentType: String) async throws {}
    }

    /// Reports a fixed presence for every path — enough to drive
    /// `PostIntegrityPolicy` without touching real Storage.
    private struct FixedPresenceImageUploader: ImageUploading {
        let presence: RemoteImagePresence
        func upload(fileURL: URL, to path: String, contentType: String) async throws {}
        func imagePresence(path: String) async -> RemoteImagePresence { presence }
    }

    /// A `PostRepository` fake whose `observePost` always yields `currentPost` (the
    /// server's current view, independent of the `post` the recovery call was given —
    /// this is what lets tests exercise the compare-and-delete guard), and which
    /// records every `deletePost` invocation.
    @MainActor
    private final class RecordingPostRepository: PostRepository {
        var currentPost: SkyPost?
        private(set) var deleteCallCount = 0
        private(set) var deletedDates: [LocalDate] = []

        init(currentPost: SkyPost?) {
            self.currentPost = currentPost
        }

        func observePost(uid: String, localDate: LocalDate) -> AsyncStream<PostObservation> {
            let value = currentPost
            return AsyncStream { continuation in
                continuation.yield(.value(value))
                continuation.finish()
            }
        }

        func observePosts(uid: String, from: LocalDate, through: LocalDate) -> AsyncStream<PostCollectionObservation> {
            AsyncStream { continuation in
                continuation.yield(.value([]))
                continuation.finish()
            }
        }

        func fetchPost(uid: String, localDate: LocalDate) async throws -> SkyPost? {
            currentPost
        }

        func createPost(_ draft: PostDraft) async throws {}

        func deletePost(uid: String, localDate: LocalDate) async throws {
            deleteCallCount += 1
            deletedDates.append(localDate)
            currentPost = nil
        }
    }

    private func makePost(imagePath: String = "posts/uid/2026-08-02/image.jpg", capturedAt: Date = Date().addingTimeInterval(-300)) -> SkyPost {
        SkyPost(
            ownerUid: "uid",
            localDate: LocalDate(year: 2026, month: 8, day: 2),
            capturedAt: capturedAt,
            uploadedAt: capturedAt,
            imagePath: imagePath,
            thumbPath: imagePath.replacingOccurrences(of: ".jpg", with: "_thumb.jpg"),
            skyColor: SkyColor(uncheckedHex: "#7EA3C8"),
            minutesFromGoal: 0,
            reactions: [:]
        )
    }

    @Test("evaluate never reports orphaned when Storage still holds the image")
    func evaluateNeverOrphansAnIntactPost() async throws {
        let post = makePost()
        let repository = RecordingPostRepository(currentPost: post)
        let queue = UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: SucceedingImageUploader())
        let recovery = OrphanedPostRecovery(postRepository: repository, uploadQueue: queue, imageStore: FixedPresenceImageUploader(presence: .present))

        let verdict = await recovery.evaluate(post: post, now: Date())
        #expect(verdict == .intact)
    }

    @Test("recover refuses to delete when Storage read is indeterminate (App Check / offline regression guard)")
    func recoverRefusesWhenIndeterminate() async throws {
        let post = makePost()
        let repository = RecordingPostRepository(currentPost: post)
        let queue = UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: SucceedingImageUploader())
        let recovery = OrphanedPostRecovery(postRepository: repository, uploadQueue: queue, imageStore: FixedPresenceImageUploader(presence: .indeterminate))

        await #expect(throws: OrphanedPostRecoveryError.notOrphaned(.undetermined)) {
            try await recovery.recover(post: post)
        }
        #expect(repository.deleteCallCount == 0)
    }

    @Test("recover deletes and clears the queue row when no local row exists at all (loss scenario b)")
    func recoverHandlesMissingQueueRow() async throws {
        let post = makePost()
        let repository = RecordingPostRepository(currentPost: post)
        let queue = UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: SucceedingImageUploader())
        let recovery = OrphanedPostRecovery(postRepository: repository, uploadQueue: queue, imageStore: FixedPresenceImageUploader(presence: .absent))

        try await recovery.recover(post: post)

        #expect(repository.deleteCallCount == 1)
        #expect(repository.deletedDates == [post.localDate])
    }

    @Test("recover deletes and discards a failed row with no recoverable local file (loss scenario a)")
    func recoverHandlesFailedRowWithNoLocalFile() async throws {
        let post = makePost()

        let imageID = UUID()
        let fullURL = try ImageFileStore.writePendingImage(Data("full".utf8), filename: "\(imageID.uuidString).jpg")
        let thumbURL = try ImageFileStore.writePendingImage(Data("thumb".utf8), filename: "\(imageID.uuidString)_thumb.jpg")
        let draft = PostDraft(
            ownerUid: post.ownerUid,
            localDate: post.localDate,
            capturedAt: post.capturedAt,
            skyColor: post.skyColor,
            minutesFromGoal: post.minutesFromGoal,
            imageID: imageID,
            localFullImageURL: fullURL,
            localThumbImageURL: thumbURL
        )
        // A terminal (permission-denied) failure drives the row straight to
        // `.failed` after one attempt — see `UploadQueue.isTerminal` — then the
        // local file is removed to reproduce the unrecoverable case
        // (`hasLocalFullImage == false`).
        struct FailingUploader: ImageUploading {
            func upload(fileURL: URL, to path: String, contentType: String) async throws {
                throw RepositoryError.permissionDenied(underlying: "App Check rejected the request.")
            }
        }
        let failingQueue = UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: FailingUploader())
        try await failingQueue.enqueue(draft)
        try await Task.sleep(nanoseconds: 300_000_000)
        ImageFileStore.deletePendingImage(at: fullURL)

        let unrecoverablePost = makePost(imagePath: draft.imagePath, capturedAt: post.capturedAt)
        let unrecoverableRepository = RecordingPostRepository(currentPost: unrecoverablePost)
        let recovery = OrphanedPostRecovery(postRepository: unrecoverableRepository, uploadQueue: failingQueue, imageStore: FixedPresenceImageUploader(presence: .absent))

        try await recovery.recover(post: unrecoverablePost)

        #expect(unrecoverableRepository.deleteCallCount == 1)
        let remaining = try await failingQueue.pendingSummary()
        #expect(remaining.isEmpty, "the failed row must be discarded once the post it belonged to is deleted")
    }

    @Test("recover throws postChanged and deletes nothing when the server doc no longer matches")
    func recoverRefusesWhenServerDocChanged() async throws {
        let judgedPost = makePost(imagePath: "posts/uid/2026-08-02/old.jpg")
        let currentPost = makePost(imagePath: "posts/uid/2026-08-02/new.jpg")
        let repository = RecordingPostRepository(currentPost: currentPost)
        let queue = UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: SucceedingImageUploader())
        let recovery = OrphanedPostRecovery(postRepository: repository, uploadQueue: queue, imageStore: FixedPresenceImageUploader(presence: .absent))

        await #expect(throws: OrphanedPostRecoveryError.postChanged) {
            try await recovery.recover(post: judgedPost)
        }
        #expect(repository.deleteCallCount == 0)
    }

    @Test("two concurrent recover calls for the same day produce exactly one delete")
    func concurrentRecoverCallsAreSerialized() async throws {
        let post = makePost()
        let repository = RecordingPostRepository(currentPost: post)
        let queue = UploadQueue(modelContainer: LocalStoreContainer.make(inMemory: true), uploader: SucceedingImageUploader())
        let recovery = OrphanedPostRecovery(postRepository: repository, uploadQueue: queue, imageStore: FixedPresenceImageUploader(presence: .absent))

        async let first: () = recovery.recover(post: post)
        async let second: () = recovery.recover(post: post)
        _ = try? await first
        _ = try? await second

        #expect(repository.deleteCallCount == 1)
    }
}

@Suite("Collection observation state")
@MainActor
struct CollectionObservationStateTests {
    private final class ValueThenUnavailablePosts: PostRepository {
        let post: SkyPost

        init(post: SkyPost) { self.post = post }

        func observePost(uid: String, localDate: LocalDate) -> AsyncStream<PostObservation> {
            AsyncStream { continuation in
                continuation.yield(.value(nil))
                continuation.finish()
            }
        }

        func observePosts(uid: String, from: LocalDate, through: LocalDate) -> AsyncStream<PostCollectionObservation> {
            AsyncStream { continuation in
                continuation.yield(.value([post]))
                continuation.yield(.unavailable)
                continuation.finish()
            }
        }

        func fetchPost(uid: String, localDate: LocalDate) async throws -> SkyPost? { post }
        func createPost(_ draft: PostDraft) async throws {}
        func deletePost(uid: String, localDate: LocalDate) async throws {}
    }

    private final class ValueThenUnavailableFriends: FriendRepository {
        let friendship: Friendship
        var requestResult: FriendRequestResult = .sent
        var acceptError: RepositoryError?
        private(set) var lastRequest: (from: String, to: String, requester: Handle, recipient: Handle)?

        init(friendship: Friendship) { self.friendship = friendship }

        func observeFriendships(uid: String) -> AsyncStream<FriendshipCollectionObservation> {
            AsyncStream { continuation in
                continuation.yield(.value([friendship]))
                continuation.yield(.unavailable)
                continuation.finish()
            }
        }

        func observeBlockedFriendships(uid: String) -> AsyncStream<BlockedFriendshipCollectionObservation> {
            AsyncStream { continuation in
                continuation.yield(.value([]))
                continuation.finish()
            }
        }

        func sendRequest(
            from: String,
            to: String,
            requesterHandle: Handle,
            recipientHandle: Handle
        ) async throws -> FriendRequestResult {
            lastRequest = (from, to, requesterHandle, recipientHandle)
            return requestResult
        }
        func acceptRequest(pairId: String, acceptingUid: String) async throws {
            if let acceptError { throw acceptError }
        }
        func removeFriendship(pairId: String) async throws {}
        func block(ownerUid: String, blockedUid: String) async throws {}
        func unblock(ownerUid: String, blockedUid: String) async throws {}
        func isBlocked(ownerUid: String, otherUid: String) async throws -> Bool { false }
    }

    private final class FixedUserRepository: UserRepository {
        func observeProfile(uid: String) -> AsyncStream<UserProfileObservation> {
            AsyncStream { continuation in
                continuation.yield(.value(UserProfile(
                    uid: uid,
                    handle: Handle(raw: "test_handle"),
                    displayName: "Tester",
                    timezone: "UTC",
                    wakeGoalMinutes: 360,
                    streakCurrent: 0,
                    streakLongest: 0,
                    lastPostLocalDate: nil,
                    isPro: false
                )))
                continuation.finish()
            }
        }

        func createOrUpdateProfile(_ profile: UserProfile) async throws {}
        func claimHandle(_ handle: Handle, for uid: String) async throws {}
        func findUid(forHandle handle: Handle) async throws -> String? { "friend" }
    }

    private final class ValueThenUnavailableUserRepository: UserRepository {
        func observeProfile(uid: String) -> AsyncStream<UserProfileObservation> {
            AsyncStream { continuation in
                continuation.yield(.value(UserProfile(
                    uid: uid,
                    handle: Handle(raw: "last_confirmed"),
                    displayName: "Last confirmed name",
                    timezone: "UTC",
                    wakeGoalMinutes: 360,
                    streakCurrent: 0,
                    streakLongest: 0,
                    lastPostLocalDate: nil,
                    isPro: false
                )))
                continuation.yield(.unavailable)
                continuation.finish()
            }
        }

        func createOrUpdateProfile(_ profile: UserProfile) async throws {}
        func claimHandle(_ handle: Handle, for uid: String) async throws {}
        func findUid(forHandle handle: Handle) async throws -> String? { nil }
    }

    private struct FailingImageFetcher: ImageFetching {
        func fetchImage(path: String) async throws -> Data {
            throw RepositoryError.network(underlying: "offline")
        }
    }

    @Test("grid keeps its last confirmed posts when the listener becomes unavailable")
    func gridPreservesLastConfirmedPosts() async {
        let date = LocalDate(year: 2026, month: 8, day: 8)
        let post = SkyPost(
            ownerUid: "uid",
            localDate: date,
            capturedAt: Date(timeIntervalSince1970: 1_786_147_200),
            uploadedAt: Date(timeIntervalSince1970: 1_786_147_260),
            imagePath: "images/full.jpg",
            thumbPath: "images/thumb.jpg",
            skyColor: SkyColor(uncheckedHex: "#91B6C8"),
            minutesFromGoal: 0,
            reactions: [:]
        )
        let viewModel = GridArchiveViewModel(
            uid: "uid",
            year: 2026,
            postRepository: ValueThenUnavailablePosts(post: post),
            imageFetching: FailingImageFetcher(),
            isPro: true,
            today: date,
            selectedMonth: 8
        )

        viewModel.start()
        for _ in 0..<8 { await Task.yield() }

        #expect(viewModel.posts[date] == post)
        #expect(viewModel.loadState == .unavailable)
    }

    @Test("buddies keep their last confirmed connections when refresh fails")
    func buddiesPreserveLastConfirmedConnections() async {
        let friendship = Friendship(
            pairId: PairID.make("uid", "friend"),
            members: ["uid", "friend"],
            status: .accepted,
            requestedBy: "uid",
            createdAt: Date(timeIntervalSince1970: 1_786_147_200),
            blockedBy: []
        )
        let viewModel = FriendsViewModel(
            uid: "uid",
            friendRepository: ValueThenUnavailableFriends(friendship: friendship),
            userRepository: FixedUserRepository()
        )

        viewModel.start()
        for _ in 0..<8 { await Task.yield() }

        #expect(viewModel.accepted == [friendship])
        #expect(viewModel.friendshipState == .unavailable)
    }

    @Test("buddy settings keep the last confirmed handle when profile refresh fails")
    func buddySettingsPreserveLastConfirmedHandle() async {
        let friendship = Friendship(
            pairId: PairID.make("uid", "friend"),
            members: ["uid", "friend"],
            status: .accepted,
            requestedBy: "uid",
            createdAt: Date(timeIntervalSince1970: 1_786_147_200),
            blockedBy: []
        )
        let viewModel = FriendsViewModel(
            uid: "uid",
            friendRepository: ValueThenUnavailableFriends(friendship: friendship),
            userRepository: ValueThenUnavailableUserRepository()
        )

        viewModel.start()
        for _ in 0..<8 { await Task.yield() }

        #expect(viewModel.handle == Handle(raw: "last_confirmed"))
        #expect(viewModel.hasHandle == true)
        #expect(viewModel.profileState == .unavailable)
    }

    @Test("sending a buddy request carries both verified handles and confirms success")
    func buddyRequestCarriesHandles() async {
        let friendship = Friendship(
            pairId: PairID.make("uid", "friend"),
            members: ["uid", "friend"],
            status: .accepted,
            requestedBy: "uid",
            createdAt: Date(timeIntervalSince1970: 1_786_147_200),
            blockedBy: []
        )
        let repository = ValueThenUnavailableFriends(friendship: friendship)
        let viewModel = FriendsViewModel(
            uid: "uid",
            friendRepository: repository,
            userRepository: FixedUserRepository()
        )
        viewModel.start()
        for _ in 0..<8 { await Task.yield() }

        let sent = await viewModel.sendRequest(toHandleRaw: "buddy_handle")

        #expect(sent)
        #expect(repository.lastRequest?.from == "uid")
        #expect(repository.lastRequest?.to == "friend")
        #expect(repository.lastRequest?.requester == Handle(raw: "test_handle"))
        #expect(repository.lastRequest?.recipient == Handle(raw: "buddy_handle"))
        #expect(viewModel.requestFeedback == .success("Request sent to @buddy_handle."))
        #expect(!viewModel.isSendingRequest)
    }

    @Test("an existing outgoing request is explained instead of silently succeeding")
    func duplicateBuddyRequestIsExplained() async {
        let friendship = Friendship(
            pairId: PairID.make("uid", "friend"),
            members: ["uid", "friend"],
            status: .pending,
            requestedBy: "uid",
            createdAt: Date(timeIntervalSince1970: 1_786_147_200),
            blockedBy: []
        )
        let repository = ValueThenUnavailableFriends(friendship: friendship)
        repository.requestResult = .alreadyPending
        let viewModel = FriendsViewModel(
            uid: "uid",
            friendRepository: repository,
            userRepository: FixedUserRepository()
        )
        viewModel.start()
        for _ in 0..<8 { await Task.yield() }

        let sent = await viewModel.sendRequest(toHandleRaw: "buddy_handle")

        #expect(!sent)
        #expect(viewModel.requestFeedback == .information("Your request to @buddy_handle is already waiting."))
    }

    @Test("accept failures remain visible and retryable")
    func buddyAcceptFailureIsVisible() async {
        let friendship = Friendship(
            pairId: PairID.make("uid", "friend"),
            members: ["uid", "friend"],
            status: .pending,
            requestedBy: "friend",
            requestedByHandle: Handle(raw: "buddy_handle"),
            recipientHandle: Handle(raw: "test_handle"),
            createdAt: Date(timeIntervalSince1970: 1_786_147_200),
            blockedBy: []
        )
        let repository = ValueThenUnavailableFriends(friendship: friendship)
        repository.acceptError = .network(underlying: "offline")
        let viewModel = FriendsViewModel(
            uid: "uid",
            friendRepository: repository,
            userRepository: FixedUserRepository()
        )

        await viewModel.accept(friendship)

        #expect(viewModel.acceptErrorMessage == "No connection. The request is still waiting; try again.")
        #expect(viewModel.acceptingPairIDs.isEmpty)
    }
}

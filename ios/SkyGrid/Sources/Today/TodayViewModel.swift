import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    struct BuddyStatus: Identifiable, Sendable {
        let uid: String
        let displayName: String
        let hasPostedToday: Bool
        let post: SkyPost?
        var id: String { uid }
    }

    private(set) var todayPost: SkyPost?
    private(set) var weekRhythm = WeekRhythm(days: [])
    private(set) var buddies: [BuddyStatus] = []
    private(set) var pendingSummary: [PendingUploadSummary] = []
    private(set) var todayIntegrity: TodayPostIntegrity = .undetermined
    private(set) var isRecoveringOrphanedPost = false
    private(set) var orphanedPostRecoveryError: String?

    private let uid: String
    private let postRepository: any PostRepository
    private let userRepository: any UserRepository
    private let friendRepository: any FriendRepository
    private let uploadQueue: UploadQueue
    private let orphanedPostRecovery: any OrphanedPostRecovering
    private let clock: Clock

    private var observationTasks: [Task<Void, Never>] = []
    private var integrityTask: Task<Void, Never>?

    init(
        uid: String,
        postRepository: any PostRepository,
        userRepository: any UserRepository,
        friendRepository: any FriendRepository,
        uploadQueue: UploadQueue,
        orphanedPostRecovery: any OrphanedPostRecovering,
        clock: Clock
    ) {
        self.uid = uid
        self.postRepository = postRepository
        self.userRepository = userRepository
        self.friendRepository = friendRepository
        self.uploadQueue = uploadQueue
        self.orphanedPostRecovery = orphanedPostRecovery
        self.clock = clock
    }

    func start() {
        let today = clock.today()

        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await post in self.postRepository.observePost(uid: self.uid, localDate: today) {
                self.todayPost = post
                self.integrityTask?.cancel()
                self.integrityTask = nil
                self.todayIntegrity = .undetermined
                self.orphanedPostRecoveryError = nil
                if let post {
                    self.integrityTask = Task { [weak self] in
                        await self?.trackIntegrity(of: post)
                    }
                }
            }
        })

        let weekStart = today.adding(days: -6)
        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await posts in self.postRepository.observePosts(uid: self.uid, from: weekStart, through: today) {
                self.weekRhythm = WeekRhythmCalculator.summarize(postedDays: posts.map(\.localDate), today: today)
            }
        })

        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await friendships in self.friendRepository.observeFriendships(uid: self.uid) {
                await self.refreshBuddies(friendships: friendships.filter { $0.status == .accepted })
            }
        })

        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.pendingSummary = (try? await self.uploadQueue.pendingSummary()) ?? []
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        })
    }

    func stop() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        integrityTask?.cancel()
        integrityTask = nil
    }

    func retryFailedUploads() async {
        for upload in pendingSummary where upload.state == .failed {
            try? await uploadQueue.retryFailed(queueID: upload.queueID)
        }
        pendingSummary = (try? await uploadQueue.pendingSummary()) ?? []
    }

    /// Deletes an orphaned "today" post (see `TodayPostIntegrity.orphaned`) so the
    /// user can record the morning again. Destructive — only call this from an
    /// explicit, user-confirmed action.
    func recoverOrphanedPost() async {
        guard let post = todayPost, todayIntegrity == .orphaned, !isRecoveringOrphanedPost else { return }
        isRecoveringOrphanedPost = true
        orphanedPostRecoveryError = nil
        defer { isRecoveringOrphanedPost = false }

        do {
            try await orphanedPostRecovery.recover(post: post)
            // `todayPost` clears itself via the `observePost` listener once the
            // delete is visible (a deleted document's snapshot decodes to `nil`);
            // don't assign it here or it would desync from that source of truth.
            integrityTask?.cancel()
            integrityTask = nil
            todayIntegrity = .undetermined
            pendingSummary = (try? await uploadQueue.pendingSummary()) ?? []
        } catch {
            orphanedPostRecoveryError = "Couldn't clear this record. Please try again."
        }
    }

    /// Polls Storage/queue state until a definitive verdict (`.intact` or
    /// `.orphaned`) is reached, then stops — a settled record has no reason to keep
    /// probing. Deliberately separate from the 2-second `pendingSummary` poll below:
    /// each check here issues a Storage `getMetadata` call, which that faster cadence
    /// would turn into needless network traffic.
    private func trackIntegrity(of post: SkyPost) async {
        while !Task.isCancelled {
            let verdict = await orphanedPostRecovery.evaluate(post: post, now: Date())
            guard !Task.isCancelled else { return }
            todayIntegrity = verdict
            if verdict == .intact || verdict == .orphaned {
                return
            }
            try? await Task.sleep(nanoseconds: 15_000_000_000)
        }
    }

    private func refreshBuddies(friendships: [Friendship]) async {
        let today = clock.today()
        var statuses: [BuddyStatus] = []
        for friendship in friendships {
            guard let otherUid = friendship.otherMember(than: uid) else { continue }
            let profileResult = await firstValue(from: userRepository.observeProfile(uid: otherUid))
            guard let profile = profileResult.flatMap({ $0 }) else { continue }
            let postResult = await firstValue(from: postRepository.observePost(uid: otherUid, localDate: today))
            let post = postResult.flatMap { $0 }
            statuses.append(BuddyStatus(uid: otherUid, displayName: profile.displayName, hasPostedToday: post != nil, post: post))
        }
        buddies = statuses
    }

    private func firstValue<T: Sendable>(from stream: AsyncStream<T>) async -> T? {
        for await value in stream {
            return value
        }
        return nil
    }
}

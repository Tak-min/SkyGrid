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

    private let uid: String
    private let postRepository: any PostRepository
    private let userRepository: any UserRepository
    private let friendRepository: any FriendRepository
    private let uploadQueue: UploadQueue
    private let clock: Clock

    private var observationTasks: [Task<Void, Never>] = []

    init(
        uid: String,
        postRepository: any PostRepository,
        userRepository: any UserRepository,
        friendRepository: any FriendRepository,
        uploadQueue: UploadQueue,
        clock: Clock
    ) {
        self.uid = uid
        self.postRepository = postRepository
        self.userRepository = userRepository
        self.friendRepository = friendRepository
        self.uploadQueue = uploadQueue
        self.clock = clock
    }

    func start() {
        let today = clock.today()

        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await post in self.postRepository.observePost(uid: self.uid, localDate: today) {
                self.todayPost = post
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

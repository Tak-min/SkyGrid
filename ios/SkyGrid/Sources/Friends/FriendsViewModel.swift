import Foundation
import Observation

@MainActor
@Observable
final class FriendsViewModel {
    private(set) var friendships: [Friendship] = []
    /// `nil` while the profile listener is connecting. A handle is intentionally
    /// requested only when someone enters the buddy feature, never at first launch.
    private(set) var hasHandle: Bool?
    var errorMessage: String?

    let uid: String
    let friendRepository: any FriendRepository
    let userRepository: any UserRepository
    private var observationTask: Task<Void, Never>?
    private var profileObservationTask: Task<Void, Never>?

    init(uid: String, friendRepository: any FriendRepository, userRepository: any UserRepository) {
        self.uid = uid
        self.friendRepository = friendRepository
        self.userRepository = userRepository
    }

    var pendingIncoming: [Friendship] {
        friendships.filter { $0.status == .pending && $0.requestedBy != uid }
    }

    var accepted: [Friendship] {
        friendships.filter { $0.status == .accepted }
    }

    func start() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await friendships in self.friendRepository.observeFriendships(uid: self.uid) {
                self.friendships = friendships
            }
        }
        profileObservationTask = Task { [weak self] in
            guard let self else { return }
            for await profile in self.userRepository.observeProfile(uid: self.uid) {
                self.hasHandle = profile?.handle != nil
            }
        }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
        profileObservationTask?.cancel()
        profileObservationTask = nil
    }

    func markHandleClaimed() {
        hasHandle = true
    }

    func sendRequest(toHandleRaw raw: String) async {
        guard let handle = Handle(raw: raw) else {
            errorMessage = "A handle must be 3–20 letters, numbers, or underscores."
            return
        }
        do {
            guard let otherUid = try await userRepository.findUid(forHandle: handle), otherUid != uid else {
                errorMessage = "No matching account was found."
                return
            }
            try await friendRepository.sendRequest(from: uid, to: otherUid)
            errorMessage = nil
        } catch {
            errorMessage = "The request could not be sent."
        }
    }

    func accept(_ friendship: Friendship) async {
        try? await friendRepository.acceptRequest(pairId: friendship.pairId, acceptingUid: uid)
    }
}

import Foundation
import Observation

@MainActor
@Observable
final class FriendsViewModel {
    enum RequestFeedback: Equatable {
        case success(String)
        case information(String)
        case failure(String)
    }

    enum FriendshipState: Equatable {
        case checking
        case available
        case unavailable
    }

    enum ProfileState: Equatable {
        case checking
        case available
        case unavailable
    }

    private(set) var friendships: [Friendship] = []
    private(set) var friendshipState: FriendshipState = .checking
    private(set) var profileState: ProfileState = .checking
    /// `nil` until a profile value has been confirmed. A handle is intentionally
    /// requested only when someone enters the buddy feature, never at first launch.
    private(set) var hasHandle: Bool?
    private(set) var handle: Handle?
    private(set) var requestFeedback: RequestFeedback?
    private(set) var isSendingRequest = false
    private(set) var acceptingPairIDs: Set<String> = []
    private(set) var acceptErrorMessage: String?

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

    var pendingOutgoing: [Friendship] {
        friendships.filter { $0.status == .pending && $0.requestedBy == uid }
    }

    var accepted: [Friendship] {
        friendships.filter { $0.status == .accepted }
    }

    func start() {
        if observationTask == nil {
            startFriendshipObservation()
        }
        if profileObservationTask == nil {
            startProfileObservation()
        }
    }

    private func startProfileObservation() {
        profileObservationTask = Task { [weak self] in
            guard let self else { return }
            for await observation in self.userRepository.observeProfile(uid: self.uid) {
                guard case .value(let profile) = observation else {
                    self.profileState = .unavailable
                    continue
                }
                self.profileState = .available
                self.handle = profile?.handle
                self.hasHandle = self.handle != nil
            }
        }
    }

    private func startFriendshipObservation() {
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await observation in self.friendRepository.observeFriendships(uid: self.uid) {
                guard case .value(let friendships) = observation else {
                    self.friendshipState = .unavailable
                    continue
                }
                self.friendshipState = .available
                self.friendships = friendships
            }
        }
    }

    func retryFriendships() {
        observationTask?.cancel()
        observationTask = nil
        friendshipState = .checking
        startFriendshipObservation()
    }

    func retryProfile() {
        profileObservationTask?.cancel()
        profileObservationTask = nil
        profileState = .checking
        startProfileObservation()
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
        profileObservationTask?.cancel()
        profileObservationTask = nil
    }

    func markHandleClaimed(_ handle: Handle) {
        self.handle = handle
        hasHandle = true
        profileState = .available
    }

    @discardableResult
    func sendRequest(toHandleRaw raw: String) async -> Bool {
        guard !isSendingRequest else { return false }
        guard let recipientHandle = Handle(raw: raw) else {
            requestFeedback = .failure("Use 3–20 letters, numbers, or underscores.")
            return false
        }
        guard let requesterHandle = handle else {
            requestFeedback = .failure("Your invite handle is not ready. Check your connection and try again.")
            return false
        }

        isSendingRequest = true
        requestFeedback = nil
        defer { isSendingRequest = false }

        do {
            guard let otherUid = try await userRepository.findUid(forHandle: recipientHandle) else {
                requestFeedback = .failure("No account uses @\(recipientHandle.value). Check the spelling and try again.")
                return false
            }
            guard otherUid != uid else {
                requestFeedback = .failure("That is your own handle. Enter your buddy's handle instead.")
                return false
            }
            let result = try await friendRepository.sendRequest(
                from: uid,
                to: otherUid,
                requesterHandle: requesterHandle,
                recipientHandle: recipientHandle
            )
            switch result {
            case .sent:
                requestFeedback = .success("Request sent to @\(recipientHandle.value).")
                return true
            case .alreadyPending:
                requestFeedback = .information("Your request to @\(recipientHandle.value) is already waiting.")
            case .incomingRequestExists:
                requestFeedback = .information("@\(recipientHandle.value) already invited you. Accept the request below.")
            case .alreadyBuddies:
                requestFeedback = .information("You and @\(recipientHandle.value) are already buddies.")
            case .blocked:
                requestFeedback = .failure("This connection can't be requested right now. Review blocked buddies in Settings.")
            }
            return false
        } catch let error as RepositoryError {
            switch error {
            case .network:
                requestFeedback = .failure("No connection. Check your network and try again.")
            case .permissionDenied:
                requestFeedback = .failure("Sky Grid couldn't verify this request. Reopen the latest version and try again.")
            case .notAuthenticated:
                requestFeedback = .failure("You're signed out. Sign in again to add a buddy.")
            default:
                requestFeedback = .failure(error.errorDescription ?? "The request could not be sent.")
            }
            return false
        } catch {
            requestFeedback = .failure("The request could not be sent. Please try again.")
            return false
        }
    }

    func accept(_ friendship: Friendship) async {
        guard !acceptingPairIDs.contains(friendship.pairId) else { return }
        acceptingPairIDs.insert(friendship.pairId)
        acceptErrorMessage = nil
        defer { acceptingPairIDs.remove(friendship.pairId) }
        do {
            try await friendRepository.acceptRequest(pairId: friendship.pairId, acceptingUid: uid)
            // A fresh pairing is the first moment there is anything for
            // `onBuddyPostCreated`'s push to notify this person about.
            await BuddyPairingNotificationPermission.requestIfNeeded()
        } catch let error as RepositoryError {
            switch error {
            case .network:
                acceptErrorMessage = "No connection. The request is still waiting; try again."
            case .permissionDenied:
                acceptErrorMessage = "This request could not be verified. Refresh your buddies and try again."
            default:
                acceptErrorMessage = error.errorDescription ?? "The request could not be accepted."
            }
        } catch {
            acceptErrorMessage = "The request could not be accepted. Please try again."
        }
    }

    func clearRequestFeedback() {
        requestFeedback = nil
    }
}

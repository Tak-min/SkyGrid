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
    private(set) var decliningPairIDs: Set<String> = []
    private(set) var declineErrorMessage: String?

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
            case .circleFull(let canUpgrade):
                requestFeedback = .failure(canUpgrade
                    ? "Free Circle holds 5 buddies. Open Settings → Sky Grid Pro for an unlimited Circle."
                    : "Your Circle has reached its capacity. Remove a buddy before sending another request.")
            case .buddyCircleFull:
                requestFeedback = .failure("This buddy's Circle is at its limit. Ask them to make room—or, on Free, open Settings → Sky Grid Pro for an unlimited Circle.")
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
        // Guard against both this method's own re-entry AND a concurrent
        // decline() on the same pairId — without the union check here, a
        // fast double-tap (accept then decline before the UI's `disabled`
        // state catches up) could accept the request via a Cloud Function
        // and then have the other in-flight task's raw document delete land
        // right after, silently erasing the freshly-created friendship.
        guard !acceptingPairIDs.contains(friendship.pairId), !decliningPairIDs.contains(friendship.pairId) else { return }
        acceptingPairIDs.insert(friendship.pairId)
        acceptErrorMessage = nil
        defer { acceptingPairIDs.remove(friendship.pairId) }
        do {
            let result = try await friendRepository.acceptRequest(pairId: friendship.pairId, acceptingUid: uid)
            switch result {
            case .accepted, .alreadyAccepted:
                // A fresh pairing is the first moment there is anything for
                // `onBuddyPostCreated`'s push to notify this person about.
                await BuddyPairingNotificationPermission.requestIfNeeded()
            case .circleFull(let canUpgrade):
                acceptErrorMessage = canUpgrade
                    ? "Free Circle holds 5 buddies. Open Settings → Sky Grid Pro for an unlimited Circle."
                    : "Your Circle has reached its capacity. Remove a buddy before accepting another request."
            case .buddyCircleFull:
                acceptErrorMessage = "This buddy's Circle is at its limit. Ask them to make room—or, on Free, open Settings → Sky Grid Pro for an unlimited Circle."
            case .invalidRequest:
                acceptErrorMessage = "This request is no longer available. Refresh your buddies and try again."
            }
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

    func decline(_ friendship: Friendship) async {
        // See accept()'s matching comment: guard on the union of both
        // in-flight sets so a concurrent accept() on the same pairId can't
        // race with this raw document delete.
        guard !decliningPairIDs.contains(friendship.pairId), !acceptingPairIDs.contains(friendship.pairId) else { return }
        decliningPairIDs.insert(friendship.pairId)
        declineErrorMessage = nil
        defer { decliningPairIDs.remove(friendship.pairId) }
        do {
            try await friendRepository.removeFriendship(pairId: friendship.pairId)
        } catch let error as RepositoryError {
            switch error {
            case .network:
                declineErrorMessage = "No connection. The request is still waiting; try again."
            case .permissionDenied:
                declineErrorMessage = "This request could not be verified. Refresh your buddies and try again."
            default:
                declineErrorMessage = error.errorDescription ?? "The request could not be declined."
            }
        } catch {
            declineErrorMessage = "The request could not be declined. Please try again."
        }
    }

    func clearRequestFeedback() {
        requestFeedback = nil
    }
}

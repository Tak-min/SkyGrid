import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    enum PostState: Equatable {
        case checking
        case available
        case unavailable
    }

    /// What the viewer is actually entitled to know about a buddy's morning.
    ///
    /// `firestore.rules` gates a buddy's post read on `hasPostedFor(localDate)` —
    /// i.e. **before you have posted, every buddy post read is denied by the
    /// server.** The previous `hasPostedToday: Bool` could not represent that, so a
    /// denied read collapsed into `false` and the UI would have told you "Mira ·
    /// not yet" every morning even when Mira had posted at 5am. That is a claim the
    /// client cannot make, so the unknown case is now explicit.
    enum BuddyRevealState: Sendable, Equatable {
        /// The viewer hasn't posted yet (or the read failed). Nothing is known —
        /// present this as sealed suspense, never as "they haven't posted".
        case sealed
        /// The viewer has posted, the read succeeded, and there is a sky to show.
        case posted(SkyPost)
        /// The viewer has posted, the read succeeded, and it genuinely returned
        /// nothing. Only in this case may the UI say "not yet".
        case notYet
    }

    struct BuddyStatus: Identifiable, Sendable {
        let uid: String
        let displayName: String
        let revealState: BuddyRevealState
        var id: String { uid }

        var post: SkyPost? {
            if case .posted(let post) = revealState { return post }
            return nil
        }
    }

    private(set) var todayPost: SkyPost?
    private(set) var postState: PostState = .checking
    private(set) var weekRhythm = WeekRhythm(days: [])
    private(set) var streak = StreakSummary(currentStreak: 0, hasPostedToday: false)
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
    /// Where the computed streak is republished for `RootView`'s post-capture moment
    /// arbitration. Optional so the UI-audit harness and tests can build a view model
    /// without one; nothing here reads it back.
    private let streakSignal: StreakSignal?
    /// Where the buddy strip's mutual-unlock count is republished for `RootView`'s
    /// first-unlock paywall. Optional for the same reason as `streakSignal`.
    private let revealSignal: RevealSignal?

    private var observationTasks: [Task<Void, Never>] = []
    private var integrityTask: Task<Void, Never>?
    private var observedDate: LocalDate?
    /// Grows via `StreakWindow.widened(forStreak:)` so a long streak is never
    /// truncated by the observation window it was computed from.
    private var streakWindowDays = StreakWindow.observedDays
    /// The accepted friendships from the most recent friendship snapshot, retained
    /// so buddies can be re-resolved when the viewer's own post appears (which is
    /// the moment the server starts permitting buddy post reads) without waiting
    /// for the friendship listener to fire again.
    private var acceptedFriendships: [Friendship] = []
    /// True once the friendship listener has delivered at least one snapshot this
    /// observation cycle. `acceptedFriendships.isEmpty` alone cannot distinguish
    /// "confirmed zero buddies" from "snapshot hasn't landed yet" — both look like an
    /// empty array — and `SoloMorningPaywallPolicy` must never treat the latter as
    /// the former, or a person who is actually paired could be flashed a solo-user
    /// paywall during the brief window before their first friendship snapshot arrives.
    private var hasResolvedFriendships = false
    /// Cancelled and replaced on every `refreshBuddies` call so a slower, earlier
    /// resolution (e.g. from the friendship listener) can never overwrite `buddies`
    /// with stale data after a faster, later one (e.g. the viewer's own post
    /// arriving) has already published the current answer.
    private var refreshBuddiesTask: Task<Void, Never>?
    /// Whether `BuddyAnalytics.mutualRevealUnlocked` has already fired for `today`,
    /// read fresh from `LocalDefaults` on each check rather than cached in an
    /// in-memory property — a process relaunch reconstructs `TodayViewModel` from
    /// scratch, and an in-memory flag would refire the metric on every relaunch
    /// after the buddy strip is already unlocked that day. Keyed by date (via
    /// `LocalDefaults.mutualRevealUnlockedLocalDate`) rather than "was the previous
    /// count zero" so it also survives `stop()`/`start(for:)` cycles unscathed:
    /// `retryPostObservation()` calls `stop()` (which clears `observedDate`) then
    /// `start(for:)` with the *same* day, and a transient Firestore read failure can
    /// drop `mutuallyUnlockedBuddyCount` from 1 back to 0 before recovering — neither
    /// should re-fire the metric this loop is measuring.
    private func hasFiredMutualRevealAnalytics(for today: LocalDate) -> Bool {
        LocalDefaults.mutualRevealUnlockedAccountID == uid
            && LocalDefaults.mutualRevealUnlockedLocalDate == today.docID
    }

    init(
        uid: String,
        postRepository: any PostRepository,
        userRepository: any UserRepository,
        friendRepository: any FriendRepository,
        uploadQueue: UploadQueue,
        orphanedPostRecovery: any OrphanedPostRecovering,
        clock: Clock,
        streakSignal: StreakSignal? = nil,
        revealSignal: RevealSignal? = nil
    ) {
        self.uid = uid
        self.postRepository = postRepository
        self.userRepository = userRepository
        self.friendRepository = friendRepository
        self.uploadQueue = uploadQueue
        self.orphanedPostRecovery = orphanedPostRecovery
        self.clock = clock
        self.streakSignal = streakSignal
        self.revealSignal = revealSignal
    }

    /// Creates exactly one listener set for an explicit local day. The view passes
    /// a freshly calculated day after midnight, a time-zone change, and foreground
    /// return, so a post from yesterday can never keep masquerading as today's.
    func start(for today: LocalDate) {
        guard observedDate != today || observationTasks.isEmpty else { return }
        stop()
        observedDate = today
        todayPost = nil
        postState = .checking
        weekRhythm = WeekRhythm(days: [])
        streak = StreakSummary(currentStreak: 0, hasPostedToday: false)
        streakWindowDays = StreakWindow.observedDays
        buddies = []
        acceptedFriendships = []
        hasResolvedFriendships = false
        pendingSummary = []
        todayIntegrity = .undetermined
        orphanedPostRecoveryError = nil

        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await observation in self.postRepository.observePost(uid: self.uid, localDate: today) {
                guard self.observedDate == today else { return }
                let hadPostedBefore = self.todayPost != nil
                switch observation {
                case .value(let post):
                    self.todayPost = post
                    self.postState = .available
                case .unavailable:
                    self.postState = .unavailable
                }
                // The transition to "posted" is exactly when the server begins
                // permitting buddy post reads (`hasPostedFor` in firestore.rules),
                // so re-resolve buddies here rather than waiting for the friendship
                // listener — which may not fire again all morning.
                if !hadPostedBefore, self.todayPost != nil, !self.acceptedFriendships.isEmpty {
                    let friendships = self.acceptedFriendships
                    Task { [weak self] in
                        await self?.refreshBuddies(friendships: friendships, today: today)
                    }
                }
                self.integrityTask?.cancel()
                self.integrityTask = nil
                self.todayIntegrity = .undetermined
                self.orphanedPostRecoveryError = nil
                if case .value(let post?) = observation {
                    self.integrityTask = Task { [weak self] in
                        await self?.trackIntegrity(of: post)
                    }
                }
            }
        })

        observeHistory(today: today, windowDays: streakWindowDays)

        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await observation in self.friendRepository.observeFriendships(uid: self.uid) {
                guard case .value(let friendships) = observation else { continue }
                let accepted = friendships.filter { $0.status == .accepted }
                self.acceptedFriendships = accepted
                self.hasResolvedFriendships = true
                await self.refreshBuddies(friendships: accepted, today: today)
            }
        })

        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard self.observedDate == today else { return }
                self.pendingSummary = ((try? await self.uploadQueue.pendingSummary()) ?? [])
                    .filter { $0.ownerUid == self.uid }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        })
    }

    /// One listener feeds both the week rhythm and the streak — they are two
    /// summaries of the same posts, so observing them separately would double the
    /// read cost for no benefit. Split out from `start(for:)` because a growing
    /// streak has to be able to re-attach this stream over a wider window.
    private func observeHistory(today: LocalDate, windowDays: Int) {
        let windowStart = today.adding(days: -(windowDays - 1))
        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await observation in self.postRepository.observePosts(uid: self.uid, from: windowStart, through: today) {
                guard self.observedDate == today else { return }
                guard case .value(let posts) = observation else {
                    // Published rather than silently skipped: a consumer must be able
                    // to tell "the streak is not known" apart from "no streak", so a
                    // failed read can never be mistaken for grounds to celebrate.
                    // The last good `weekRhythm`/`streak` are intentionally kept.
                    self.streakSignal?.record(.unavailable(localDate: today))
                    continue
                }
                let postedDays = posts.map(\.localDate)
                self.weekRhythm = WeekRhythmCalculator.summarize(posts: posts, today: today)
                // `exemptDays` is empty on purpose: `RestDayPolicy` has no
                // persistence and `TimeZonePolicy` has no change-log producer, so
                // there is currently no honest source of exempt days. See the
                // dev-note — enabling them is a product decision, not a UI one.
                self.streak = StreakCalculator.summarize(postedDays: postedDays, today: today)

                if StreakWindow.needsWidening(streak: self.streak.currentStreak, windowDays: windowDays) {
                    let widened = StreakWindow.widened(forStreak: self.streak.currentStreak)
                    if widened > windowDays {
                        self.streakWindowDays = widened
                        self.observeHistory(today: today, windowDays: widened)
                        return
                    }
                }

                // Republished only once the window is known not to be truncating the
                // streak, so a milestone can never be celebrated on a number that the
                // very next (wider) snapshot would revise upward.
                self.streakSignal?.record(
                    .observed(
                        localDate: today,
                        summary: self.streak,
                        post: posts.first { $0.localDate == today }
                    )
                )
            }
        })
    }

    func stop() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        integrityTask?.cancel()
        integrityTask = nil
        refreshBuddiesTask?.cancel()
        refreshBuddiesTask = nil
        observedDate = nil
        acceptedFriendships = []
        hasResolvedFriendships = false
    }

    /// Re-checks the buddy strip without waiting for a listener to re-emit.
    /// `refreshBuddies` only ever runs from two triggers today — the viewer's own
    /// post appearing, and the friendship listener re-emitting — neither of which
    /// fires when a buddy posts while this app is simply sitting in the background.
    /// A Firestore snapshot listener would normally catch that on its own, but
    /// `refreshBuddies` deliberately takes one snapshot per buddy and lets its
    /// stream terminate (see its doc comment) rather than holding a live listener
    /// open per buddy. Call this on scene-phase-active to cover "the app was
    /// backgrounded when a buddy posted and is only now being reopened." A buddy
    /// posting while this app is already foregrounded is covered separately:
    /// `RootView` also calls this (via `TodayView`'s `buddyRefreshToken`) whenever
    /// `onBuddyPostCreated`'s push notification arrives, tapped or merely delivered
    /// — see `NotificationRouter` and `AppRouter.buddyRevealRefreshTicks`.
    /// `dev-notes/invite-link-ios-blueprint_2026-08-11.md` recorded that gap as
    /// deliberately deferred; the push closes it without a live per-buddy listener
    /// or a foreground poll.
    func refreshBuddiesNow() {
        guard let today = observedDate, !acceptedFriendships.isEmpty else { return }
        Task { await refreshBuddies(friendships: acceptedFriendships, today: today) }
    }

    /// Firestore listeners normally recover themselves, but a visible retry gives
    /// someone a deterministic way out after a prolonged offline/App Check error.
    /// This only reconnects read observers; it never creates or deletes a post.
    func retryPostObservation() {
        guard let date = observedDate else { return }
        stop()
        start(for: date)
    }

    func retryFailedUploads() async {
        for upload in pendingSummary where upload.state == .failed || upload.state == .postFailed {
            try? await uploadQueue.retryFailed(queueID: upload.queueID)
        }
        pendingSummary = ((try? await uploadQueue.pendingSummary()) ?? [])
            .filter { $0.ownerUid == uid }
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
            pendingSummary = ((try? await uploadQueue.pendingSummary()) ?? [])
                .filter { $0.ownerUid == uid }
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

    /// Serializes every call through one cancel-and-replace task, so two triggers
    /// landing close together (the friendship listener re-emitting right as the
    /// viewer's own post arrives, say) can never interleave and let the one that
    /// happens to *complete* later win regardless of which one *started* later.
    private func refreshBuddies(friendships: [Friendship], today: LocalDate) async {
        refreshBuddiesTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefreshBuddies(friendships: friendships, today: today)
        }
        refreshBuddiesTask = task
        await task.value
    }

    /// Resolves the buddy strip. The viewer's own post is the gate: until it exists,
    /// `firestore.rules` denies every buddy post read (`hasPostedFor`), so issuing
    /// them would be a guaranteed-failing round-trip per buddy, per session, whose
    /// only possible result is the `.sealed` state we can already infer. Skipping
    /// them removes that waste and — more importantly — removes the temptation to
    /// render a denied read as "hasn't posted".
    private func performRefreshBuddies(friendships: [Friendship], today: LocalDate) async {
        let isRevealed = BuddyRevealGate.isRevealed(viewerHasPostedToday: todayPost != nil)
        var statuses: [BuddyStatus] = []
        for friendship in friendships {
            guard let otherUid = friendship.otherMember(than: uid) else { continue }
            let profileResult = await firstValue(from: userRepository.observeProfile(uid: otherUid))
            guard case .value(let profile?)? = profileResult else { continue }
            guard !Task.isCancelled, observedDate == today else { return }

            let revealState: BuddyRevealState
            if !isRevealed {
                revealState = .sealed
            } else {
                let postResult = await firstValue(from: postRepository.observePost(uid: otherUid, localDate: today))
                guard !Task.isCancelled, observedDate == today else { return }
                switch postResult {
                case .value(let post?):
                    revealState = .posted(post)
                case .value(nil):
                    revealState = .notYet
                case .unavailable, .none:
                    // A failed read is not evidence of absence. Fall back to sealed
                    // rather than claiming they haven't posted.
                    revealState = .sealed
                }
            }
            statuses.append(BuddyStatus(uid: otherUid, displayName: profile.displayName, revealState: revealState))
        }
        guard !Task.isCancelled, observedDate == today else { return }
        buddies = statuses
        // `.posted` only appears once `firestore.rules`' `activeBuddy(uid) &&
        // hasPostedFor(localDate)` has actually permitted the read, so this count is
        // server-verified proof of mutual unlock, not a client inference.
        let unlockedCount = statuses.filter { if case .posted = $0.revealState { true } else { false } }.count
        revealSignal?.record(RevealReading(
            localDate: today,
            mutuallyUnlockedBuddyCount: unlockedCount,
            acceptedBuddyCount: hasResolvedFriendships ? friendships.count : nil
        ))
        // The target metric this loop is optimizing for (see
        // dev-notes/virality-stickiness-assessment_2026-09-04.md): fire exactly once
        // per day, on the 0→≥1 transition, never on every re-resolution (the
        // friendship/post listeners can both re-emit the same already-unlocked state,
        // and a transient read failure can drop the count back to 0 and recover —
        // see `hasFiredMutualRevealAnalytics`'s doc comment for why this is keyed by
        // date, persisted, and not by the previous in-memory count).
        if unlockedCount >= 1, !hasFiredMutualRevealAnalytics(for: today) {
            BuddyAnalytics.record(.mutualRevealUnlocked, unlockedBuddyCount: unlockedCount)
            LocalDefaults.mutualRevealUnlockedAccountID = uid
            LocalDefaults.mutualRevealUnlockedLocalDate = today.docID
        }
    }

    private func firstValue<T: Sendable>(from stream: AsyncStream<T>) async -> T? {
        for await value in stream {
            return value
        }
        return nil
    }
}

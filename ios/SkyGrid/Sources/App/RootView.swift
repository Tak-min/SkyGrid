import Combine
import SwiftUI

struct RootView: View {
    @Environment(\.appServices) private var appServices
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @State private var destination: LaunchDestination = LaunchGate.destination(onboardingDone: LocalDefaults.onboardingDone)
    @State private var presentations = RootPresentationCoordinator()
    @State private var cameraRouteTask: Task<Void, Never>?
    @State private var isReconcilingRitual = false
    @State private var paywallEntryPoint: PaywallEntryPoint = .home
    @State private var postCaptureBackstop: Task<Void, Never>?
    @State private var observedLocalDate: LocalDate?
    /// Receives the streak from `TodayViewModel` — the only thing that computes it.
    /// RootView owns post-capture arbitration but holds no reference to that view
    /// model (`TodayView` captures it as `@State`), so the value is published up here
    /// rather than recomputed, which would be a second source of truth.
    @State private var streakSignal = StreakSignal()
    /// Receives the buddy strip's mutual-unlock count from `TodayViewModel` — the
    /// only thing that computes it. Mirrors `streakSignal` exactly: `TodayViewModel`
    /// is reconstructed on every `RootView` body evaluation and only survives via
    /// `TodayView`'s own `@State`, so this must be injected from here rather than
    /// left for the view model to create, or a freshly-made signal would silently
    /// drop every reading.
    @State private var revealSignal = RevealSignal()
    @State private var postCaptureArming: PostCaptureArming?
    /// Set only when a milestone outranks an eligible solo paywall, to the exact
    /// capture day that made it eligible. See the write site in
    /// `resolvePostCaptureMoment` and the read site in `resolveSoloPaywall` for why
    /// this must be the frozen `LocalDate` rather than a `Bool` re-derived as
    /// "today" — a calendar-day rollover between the defer and the re-ask would
    /// otherwise stop it matching `revealSignal.reading`.
    @State private var deferredSoloPaywallDate: LocalDate?
    /// Bumped every time `consumePendingBuddyRevealIfNeeded()` acts on a buddy-post
    /// push, so `TodayView` can re-resolve the buddy strip via
    /// `TodayViewModel.refreshBuddiesNow()` — mirrors `streakSignal`/`revealSignal`:
    /// passed down as a plain value rather than left for the view model to own,
    /// since `TodayViewModel` is reconstructed on every body evaluation.
    @State private var buddyRefreshToken = 0
    /// Set the instant `PostPublisher.publish` succeeds — the same truth gate
    /// `Haptics.postCompleted()` and `recordCompletedCapture` already use. Unlike
    /// `postCaptureArming`, this never waits on `streakSignal`: DESIGN.md's daily
    /// reward only needs "did the capture durably save", which is already known
    /// synchronously in `cameraSheet`'s `onConfirmed` closure.
    /// Armed by `recordCompletedCapture`, while the camera is still on screen, and
    /// claimed by the shared full-screen `onDismiss` the next time it fires — in
    /// practice always the camera's own dismissal, since nothing else is on screen
    /// while this is armed — mirrors why `onDismiss` (not the
    /// `onConfirmed` closure itself) is where `milestoneMoment`/paywall presentation
    /// already happens: presenting a new full-screen cover from the same runloop as
    /// this one's dismissal animation can swallow it.
    @State private var pendingReward: RewardMoment?
    /// Secondary places remain reachable from the daily record, but are not peer
    /// destinations in a general-purpose tab bar. This keeps the morning action and
    /// its growing mosaic in one causal home while retaining every existing screen.
    @State private var homeDestination: HomeDestination?
    @State private var hasHandledInitialHomeRoute = false
    let onAccountDeleted: () -> Void

    private var showCamera: Bool {
        get { if case .camera = presentations.active { return true }; return false }
        nonmutating set { if newValue { presentations.present(.camera) } else if showCamera { presentations.dismiss() } }
    }
    private var showPaywall: Bool {
        get { if case .paywall = presentations.active { return true }; return false }
        nonmutating set { if newValue { presentations.present(.paywall) } else if showPaywall { presentations.dismiss() } }
    }
    private var rewardMoment: RewardMoment? {
        get { if case .reward(let moment) = presentations.active { return moment }; return nil }
        nonmutating set { if let newValue { presentations.present(.reward(newValue)) } else if rewardMoment != nil { presentations.dismiss() } }
    }
    private var milestoneMoment: MilestoneMoment? {
        get { if case .milestone(let moment) = presentations.active { return moment }; return nil }
        nonmutating set { if let newValue { presentations.present(.milestone(newValue)) } else if milestoneMoment != nil { presentations.dismiss() } }
    }
    private var inviteMoment: InviteCode? {
        get { if case .invite(let code) = presentations.active { return code }; return nil }
        nonmutating set { if let newValue { presentations.present(.invite(newValue)) } else if inviteMoment != nil { presentations.dismiss() } }
    }

    var body: some View {
        Group {
            if let services = appServices {
                content(services: services)
                    .task(id: services.currentUid) {
                        refreshObservedLocalDate(services: services)
                        refreshDestination(services: services)
                        await restorePendingRewardIfNeeded(services: services)
                        await services.entitlements.refresh()
                        resolvePendingPresentations(services: services)
                    }
                    .onAppear {
                        refreshObservedLocalDate(services: services)
                        consumePendingCameraRequestIfNeeded()
                        consumePendingBuddyRevealIfNeeded()
                        resolvePendingPresentations(services: services)
                        Task { await reconcileMorningRitual(services: services) }
                    }
                    .onChange(of: scenePhase) { _, phase in
                        guard phase == .active else { return }
                        refreshObservedLocalDate(services: services)
                        consumePendingCameraRequestIfNeeded()
                        consumePendingBuddyRevealIfNeeded()
                        resolvePendingPresentations(services: services)
                        Task { await reconcileMorningRitual(services: services) }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                        refreshObservedLocalDate(services: services)
                        // A prior day's card must not remain in the Island until
                        // the next foreground transition. Reconcile immediately
                        // when iOS rolls the local calendar over.
                        Task { await reconcileMorningRitual(services: services) }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                        refreshObservedLocalDate(services: services)
                        Task { await reconcileMorningRitual(services: services) }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                        // Covers a manual clock change and large system time jump.
                        // Clear/rebind Today immediately rather than waiting for a
                        // foreground transition that may never occur.
                        refreshObservedLocalDate(services: services)
                        Task { await reconcileMorningRitual(services: services) }
                    }
                    .onChange(of: destination) { _, _ in
                        consumePendingCameraRequestIfNeeded()
                        consumePendingBuddyRevealIfNeeded()
                        resolvePendingPresentations(services: services)
                    }
                    .onChange(of: services.entitlements.status) { _, _ in
                        resolvePendingPresentations(services: services)
                    }
                    // Must live here, not on `todayFlow`: leaving `.today` removes
                    // that subtree in the same update, so an `onChange` inside it
                    // never runs. Nothing presented below can still be on screen
                    // once this is not `.today`, so holding the lease past that
                    // point can only ever be a leak — see `releaseUnpresented()`.
                    .onChange(of: destination) { _, value in
                        guard value != .today else { return }
                        presentations.releaseUnpresented()
                    }
            } else {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private func content(services: AppServices) -> some View {
        switch destination {
        case .onboarding:
            OnboardingCoordinatorView(
                purchases: services.purchases,
                entitlements: services.entitlements,
                uid: services.currentUid,
                userRepository: services.userRepository,
                inviteRepository: services.inviteRepository
            ) {
                refreshDestination(services: services)
            }
        case .today:
            todayFlow(services: services)
        }
    }

    @ViewBuilder
    private func todayFlow(services: AppServices) -> some View {
        let today = observedLocalDate ?? services.clock.today()
        NavigationStack {
            TodayView(
                viewModel: TodayViewModel(
                    uid: services.currentUid,
                    postRepository: services.postRepository,
                    userRepository: services.userRepository,
                    friendRepository: services.friendRepository,
                    uploadQueue: services.uploadQueue,
                    orphanedPostRecovery: services.orphanedPostRecovery,
                    clock: services.clock,
                    streakSignal: streakSignal,
                    revealSignal: revealSignal
                ),
                imageFetching: services.imageFetching,
                observedDate: today,
                onOpenCamera: { showCamera = true },
                subscriptionPlan: services.entitlements.plan,
                onOpenGrid: { homeDestination = .archive },
                onOpenBuddies: { homeDestination = .buddies },
                buddyRefreshToken: buddyRefreshToken,
                onSharePresentationChanged: { presented in
                    presentations.childIsPresented = presented
                },
                onShareDismissed: {
                    resolvePendingPresentations(services: services)
                    consumePendingCameraRequestIfNeeded()
                }
            )
            .tint(SGT.ink)
            .navigationDestination(item: $homeDestination) { destination in
                switch destination {
                case .archive:
                    SkyGridArchiveTab(
                        uid: services.currentUid,
                        currentYear: services.clock.today().year,
                        postRepository: services.postRepository,
                        imageFetching: services.imageFetching,
                        uploadQueue: services.uploadQueue,
                        isPro: services.entitlements.isPro,
                        today: services.clock.today(),
                        onUpgrade: { presentPaywall(from: .archive) }
                    )
                case .buddies:
                    BuddiesView(
                        uid: services.currentUid,
                        friendRepository: services.friendRepository,
                        userRepository: services.userRepository,
                        contentSafetyRepository: services.contentSafetyRepository,
                        inviteRepository: services.inviteRepository,
                        revealSignal: revealSignal,
                        imageFetching: services.imageFetching,
                        clock: services.clock
                    )
                case .settings:
                    SettingsView(
                        uid: services.currentUid,
                        accountDeletionService: services.accountDeletionService,
                        friendRepository: services.friendRepository,
                        userRepository: services.userRepository,
                        purchases: services.purchases,
                        entitlements: services.entitlements,
                        onAccountDeleted: onAccountDeleted
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Explore", systemImage: "square.grid.3x3") {
                        Button("Sky Grid", systemImage: "square.grid.3x3.fill") {
                            homeDestination = .archive
                        }
                        Button("Buddies", systemImage: "person.2.fill") {
                            homeDestination = .buddies
                        }
                    }
                    .accessibilityLabel("Explore Sky Grid and Buddies")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        homeDestination = .settings
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Open settings")
                }
            }
        }
        .fullScreenCover(item: presentations.binding(fullScreen: true), onDismiss: {
            presentationDidDismiss(services: services)
        }) { presentation in
            switch presentation {
            case .camera:
                cameraSheet(services: services)
            case .reward(let moment):
                RewardOverlayView(moment: moment, revealSignal: revealSignal, imageFetching: services.imageFetching) {
                    presentations.dismiss()
                }
            case .milestone(let moment):
                MilestoneView(moment: moment, inviteRepository: services.inviteRepository) {
                    presentations.dismiss()
                }
            case .paywall, .invite:
                EmptyView()
            }
        }
        .onChange(of: streakSignal.reading) { _, _ in
            // The other half of the resolution: the streak usually lands after the
            // camera is gone, so whichever event is second finds the arming intact.
            resolvePendingPresentations(services: services)
        }
        .onChange(of: revealSignal.reading) { _, _ in
            resolvePendingPresentations(services: services)
        }
        .sheet(item: presentations.binding(fullScreen: false), onDismiss: {
            presentationDidDismiss(services: services)
        }) { presentation in
            switch presentation {
            case .paywall:
                PaywallView(
                purchases: services.purchases,
                entryPoint: paywallEntryPoint,
                allowsSecondChance: SecondChancePaywallPolicy.shouldAttempt(
                    entryPoint: paywallEntryPoint,
                    hasPresentedForAccount: LocalDefaults.hasPresentedSecondChancePaywall(
                        for: services.currentUid
                    )
                ),
                onEntitlementGranted: {
                    await services.entitlements.refresh()
                    // A purchase from the solo paywall resolves its cadence — there
                    // is nothing left to snooze once someone has subscribed.
                    if case .soloMorning = paywallEntryPoint {
                        LocalDefaults.consecutiveSoloPaywallDismissals = 0
                        LocalDefaults.soloPaywallSnoozedUntil = nil
                    }
                },
                onPresented: { recordAutomaticPaywallPresentationIfNeeded(services: services) },
                onDismissed: recordSoloPaywallDismissalIfNeeded,
                onSecondChancePresented: {
                    LocalDefaults.markSecondChancePaywallPresented(for: services.currentUid)
                }
            )
            case .invite(let code):
                InviteClaimView(
                code: code,
                uid: services.currentUid,
                inviteRepository: services.inviteRepository,
                userRepository: services.userRepository,
                onFinished: { presentations.dismiss() }
            )
            case .camera, .reward, .milestone:
                EmptyView()
            }
        }
        .onChange(of: homeDestination) { _, value in
            guard value == nil else { return }
            consumePendingCameraRequestIfNeeded()
            resolvePendingPresentations(services: services)
        }
        .task { consumePendingCameraRequestIfNeeded() }
        .task { consumePendingBuddyRevealIfNeeded() }
        .task { openInitialHomeRouteIfNeeded() }
        .onChange(of: router.buddyRevealRefreshTicks) { _, _ in
            // A buddy-post push that arrived while this app was already foregrounded
            // is not a tap — nobody navigated — but the strip should still catch up.
            // Safe to react to directly, unlike `pendingBuddyRevealRoute`: this only
            // ever changes while the app (and this observing view) is already alive.
            buddyRefreshToken += 1
        }
        .task { resolvePendingPresentations(services: services) }
    }

    private func cameraSheet(services: AppServices) -> some View {
        let cameraSource = services.cameraSourceFactory()
        let today = services.clock.today()
        let requiresCapture = MorningAlarmScheduler.hasActiveCaptureRequiredSession(
            today: today,
            now: services.clock.now
        )
        return CameraView(
            viewModel: CameraViewModel(
                ownerUid: services.currentUid,
                cameraSource: cameraSource,
                clock: services.clock,
                wakeGoal: WakeGoal(minutesAfterMidnight: LocalDefaults.wakeGoalMinutes)
            ),
            liveSession: cameraSource.session,
            requiresCaptureToDismiss: requiresCapture,
            onDismiss: { showCamera = false },
            onEndRequiredCapture: {
                await MorningAlarmScheduler.endActiveCaptureRequiredSession(
                    reason: .userEndedAfterFailure
                )
            },
            onConfirmed: { draft in
                try await services.postPublisher.publish(draft)
                await MorningRitualCoordinator.captureCompleted(localDate: draft.localDate)
                recordCompletedCapture(draft, services: services)
                showCamera = false
                Task {
                    await services.entitlements.refresh()
                    resolvePendingPresentations(services: services)
                }
            }
        )
    }

    private func refreshDestination(services: AppServices) {
        let isUITestFastPath = ProcessInfo.processInfo.arguments.contains("-SkyGridSkipOnboarding")
        destination = LaunchGate.destination(
            onboardingDone: LocalDefaults.onboardingDone || isUITestFastPath
        )
    }

    private func refreshObservedLocalDate(services: AppServices) {
        let current = services.clock.today()
        guard observedLocalDate != current else { return }
        observedLocalDate = current
    }

    private func presentPaywall(from entryPoint: PaywallEntryPoint) {
        guard presentations.isAvailable else { return }
        paywallEntryPoint = entryPoint
        showPaywall = true
    }

    /// A successful capture means the Firestore record and durable local upload
    /// outbox were both written. The remote image upload can finish later, so this
    /// deliberately measures completed captures rather than uploaded photos — that
    /// count still feeds `AppReviewPromptPolicy` and `FirstUnlockPaywallPolicy`'s
    /// `minimumCompletedCaptures` floor. Eligibility for the first-unlock paywall
    /// itself is no longer decided here: unlike the retired capture-count reminder,
    /// it can become true asynchronously (a buddy posting hours later), so
    /// `resolvePostCaptureMoment`/`resolveFirstUnlockPaywall` compute it fresh at
    /// every re-ask instead of freezing it into the arming.
    private func recordCompletedCapture(_ draft: PostDraft, services: AppServices) {
        prepareAutomaticPaywallState(for: draft.ownerUid)
        armDailyReward(draft: draft)
        guard LocalDefaults.lastCompletedCaptureLocalDate != draft.localDate.docID else { return }

        LocalDefaults.lastCompletedCaptureLocalDate = draft.localDate.docID
        LocalDefaults.completedCaptureCount += 1
        let count = LocalDefaults.completedCaptureCount

        armPostCaptureMoment(
            localDate: draft.localDate,
            completedCaptureCount: count,
            uid: draft.ownerUid,
            services: services
        )
    }

    /// Arms the daily reward the instant `PostPublisher.publish` succeeds — the same
    /// durable-local-write success `Haptics.postCompleted()` already reacts to.
    /// Unlike `armPostCaptureMoment`, this never waits on `streakSignal`: DESIGN.md's
    /// truth gate for the reward is publish success itself, not the streak that
    /// answers a separate milestone/paywall question. `DailyRewardPolicy` bounds it
    /// to at most once per successful post, matching the "plays at most once for
    /// that successful post" rule in the daily reward motion contract.
    /// Rebuilds a reward the process died holding. Bounded to today by
    /// `PendingRewardStore.load(today:)` and to "not already shown" by the same
    /// `DailyRewardPolicy` gate the arming path uses, so this can never manufacture a
    /// second celebration for a morning that already had one.
    private func restorePendingRewardIfNeeded(services: AppServices) async {
        guard pendingReward == nil else { return }
        let today = services.clock.today()
        guard DailyRewardPolicy.shouldPlay(
            for: today,
            lastPlayedLocalDate: LocalDefaults.lastRewardPlayedLocalDate
        ), let record = PendingRewardStore.standard.load(today: today) else { return }

        // Off the main actor: this runs during launch, and the bytes are only ever a
        // nicety — `RewardOverlayView` falls back to the recorded sky colour.
        let path = record.thumbPath
        let thumbnailData = await Task.detached(priority: .userInitiated) {
            ImageFileStore.pendingImageData(forRemotePath: path)
                ?? ImageFileStore.cachedThumbnailData(forRemotePath: path)
        }.value
        guard pendingReward == nil else { return }
        pendingReward = RewardMoment(
            localDate: record.localDate,
            skyColor: record.skyColor,
            thumbnailData: thumbnailData
        )
    }

    private func armDailyReward(draft: PostDraft) {
        guard DailyRewardPolicy.shouldPlay(
            for: draft.localDate,
            lastPlayedLocalDate: LocalDefaults.lastRewardPlayedLocalDate
        ) else { return }

        // Deliberately NOT marked played here. Writing the flag at arming time meant a
        // process death between the publish and the presentation permanently suppressed
        // that day's reward: the flag said "played" while nothing ever played. The write
        // happens where the reward reaches the screen, in `resolvePendingPresentations`.
        //
        // The moment itself is recorded durably for the same reason — see
        // `PendingRewardStore` and `restorePendingRewardIfNeeded`.
        PendingRewardStore.standard.save(
            PendingRewardRecord(
                localDate: draft.localDate,
                skyColor: draft.skyColor,
                thumbPath: draft.thumbPath
            )
        )
        pendingReward = RewardMoment(
            localDate: draft.localDate,
            skyColor: draft.skyColor,
            thumbnailData: try? Data(contentsOf: draft.localThumbImageURL)
        )
    }

    /// Records a completed capture so the milestone/paywall/review question can be
    /// answered once the streak arrives — which is after this returns.
    private func armPostCaptureMoment(
        localDate: LocalDate,
        completedCaptureCount: Int,
        uid: String,
        services: AppServices
    ) {
        prepareMilestoneState(for: uid)
        postCaptureArming = PostCaptureArming(
            localDate: localDate,
            completedCaptureCount: completedCaptureCount,
            armedAt: Date()
        )

        // Resolution is normally driven by two events: the camera's dismissal and the
        // streak arriving. Neither is guaranteed — if the history listener is not
        // attached at all, no reading ever lands and nothing would ask again, which
        // would silently cost an eligible paywall its turn. This one-shot backstop
        // fires the question again after the arming's lifetime, at which point
        // `decide` stops waiting for the streak. It is not a presentation delay: the
        // camera is long gone by then, and `resolvePostCaptureMoment` still guards on
        // no other modal being up.
        postCaptureBackstop?.cancel()
        postCaptureBackstop = Task { @MainActor in
            let nanoseconds = UInt64((PostCaptureMomentPolicy.armingLifetime + 0.5) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            resolvePostCaptureMoment(services: services)
        }

        resolvePostCaptureMoment(services: services)
    }

    /// Retires the capture's claim to a moment and stops the backstop that would
    /// otherwise ask about it again. Every terminal branch of the resolution goes
    /// through here, so "consumed exactly once" is one fact in one place.
    private func consumePostCaptureArming() {
        postCaptureArming = nil
        postCaptureBackstop?.cancel()
        postCaptureBackstop = nil
    }

    /// Re-asks `PostCaptureMomentPolicy` whenever something that could change its
    /// answer happened. Safe to call repeatedly: the arming is consumed exactly once,
    /// and an unanswerable question leaves it armed for the next event.
    private func resolvePostCaptureMoment(services: AppServices) {
        guard let arming = postCaptureArming else { return }
        // Never stack one of these on top of another modal. The camera in particular:
        // presenting while it is dismissing races iOS's own animation.
        // The reward owns the full-screen presentation slot until its own dismissal
        // callback re-asks this resolver. In particular, the first asynchronous
        // streak reading for a Day-1 capture can arrive during the reward; without
        // this guard SwiftUI is asked to present reward and milestone covers at once.
        guard canPresentAutomaticMoment else { return }

        prepareUnlockPaywallState(for: services.currentUid)
        let isFirstUnlockEligible = FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: services.entitlements.status,
            reading: revealSignal.reading,
            completedCaptureCount: LocalDefaults.completedCaptureCount,
            hasPresentedUnlockPaywall: LocalDefaults.unlockPaywallPresentedAt != nil
        )

        prepareSoloPaywallState(for: services.currentUid)
        let soloVerdict = SoloMorningPaywallPolicy.evaluate(
            entitlementStatus: services.entitlements.status,
            reading: revealSignal.reading,
            completedCaptureCount: LocalDefaults.completedCaptureCount,
            captureLocalDate: arming.localDate,
            lastPromptedCaptureCount: LocalDefaults.lastSoloPaywallPromptCaptureCount,
            lastPromptedLocalDate: LocalDefaults.lastSoloPaywallPromptLocalDate.flatMap(LocalDate.init(docID:)),
            snoozedUntil: LocalDefaults.soloPaywallSnoozedUntil,
            now: Date()
        )
        let isSoloEligible = soloVerdict == .present

        // A mutually-unlocked buddy (`isFirstUnlockEligible`) and zero accepted
        // buddies (`isSoloEligible`) can never both be true — `mutuallyUnlockedBuddyCount`
        // only counts up from `acceptedBuddyCount`, which `SoloMorningPaywallPolicy`
        // requires to be exactly `0` — so at most one automatic offer is ever live.
        switch PostCaptureMomentPolicy.decide(
            arming: arming,
            isPaywallEligible: isFirstUnlockEligible || isSoloEligible,
            reading: streakSignal.reading,
            lastCelebratedMilestone: LocalDefaults.lastCelebratedStreakMilestone,
            hasRequestedAppReview: LocalDefaults.hasRequestedAppReview,
            now: Date()
        ) {
        case .awaitingStreak:
            return
        case .none:
            consumePostCaptureArming()
        case .paywall:
            consumePostCaptureArming()
            // Recorded as a presentation only here, on the path that actually shows
            // it (`recordAutomaticPaywallPresentationIfNeeded`). A deferred paywall
            // (the milestone branch below wins instead) records nothing, which is
            // exactly what lets the very next re-ask offer it again.
            presentPaywall(from: isFirstUnlockEligible ? .firstUnlock : .soloMorning(captureCount: arming.completedCaptureCount))
        case .milestone(let milestone):
            guard case .observed(_, _, let post?) = streakSignal.reading else {
                // `decide` already proved this, but reading the post back out is what
                // actually builds the card — never force-unwrap that proof.
                return
            }
            // Persisted *before* presenting, so a re-entrant resolution or a crash
            // mid-presentation can never produce the same celebration twice.
            LocalDefaults.lastCelebratedStreakMilestone = milestone.streak
            // The paywall defers to the next re-ask by simply not happening here —
            // for the solo paywall specifically, remember which capture day made it
            // eligible so `resolveSoloPaywall` can still match it against
            // `revealSignal.reading` even across a calendar-day rollover.
            if isSoloEligible {
                deferredSoloPaywallDate = arming.localDate
            }
            consumePostCaptureArming()
            milestoneMoment = MilestoneMoment(
                milestone: milestone,
                post: post,
                photo: localPhoto(for: post),
                handle: LocalDefaults.handle.flatMap(Handle.init(raw:))
            )
        case .reviewPrompt:
            consumePostCaptureArming()
            LocalDefaults.hasRequestedAppReview = true
            requestReview()
        }
    }

    /// Reads the morning's image from local disk only. Immediately after a capture the
    /// pending-upload file is guaranteed present (`PostPublisher.publish` writes the
    /// JPEG to the outbox before Firestore), so the moment works offline and never
    /// waits on a download. `nil` is fine — the card degrades to the sky colour.
    ///
    /// Synchronous on the main actor, for simplicity rather than for correctness:
    /// `resolvePostCaptureMoment` has no suspension points today, and by the time this
    /// is called the double-fire guards above it — the `lastCelebratedStreakMilestone`
    /// write and `postCaptureArming = nil` — have already run, so a concurrent
    /// resolution would bail at this function's first `guard`. Making this `async`
    /// would therefore be safe; it simply is not worth it for one small local JPEG
    /// read that happens a handful of times per install. Do not copy the blocking read
    /// into anything that runs per frame or per row.
    private func localPhoto(for post: SkyPost) -> UIImage? {
        let data = ImageFileStore.pendingImageData(forRemotePath: post.imagePath)
            ?? ImageFileStore.cachedImageData(forRemotePath: post.imagePath)
        return data.flatMap(UIImage.init(data:))
    }

    /// The first-unlock paywall's other trigger, for when a buddy is mutually
    /// revealed with no capture in flight (they post hours after the viewer did, or
    /// the viewer simply reopens the app on a later morning). `resolvePostCaptureMoment`
    /// computes this same eligibility inline when an arming *is* in flight, because
    /// that path also has to weigh a milestone against it — this one has nothing to
    /// arbitrate against, so it can act the moment eligibility is true.
    private func resolveFirstUnlockPaywall(services: AppServices) {
        guard canPresentAutomaticMoment else { return }
        // A capture is currently being arbitrated — that path owns this decision so
        // a milestone can still outrank the paywall; this resolver only ever handles
        // the case where there is nothing else in flight to arbitrate against.
        guard postCaptureArming == nil else { return }

        prepareUnlockPaywallState(for: services.currentUid)
        guard FirstUnlockPaywallPolicy.shouldPresent(
            entitlementStatus: services.entitlements.status,
            reading: revealSignal.reading,
            completedCaptureCount: LocalDefaults.completedCaptureCount,
            hasPresentedUnlockPaywall: LocalDefaults.unlockPaywallPresentedAt != nil
        ) else { return }

        presentPaywall(from: .firstUnlock)
    }

    /// Mirrors `resolveFirstUnlockPaywall`: the solo paywall's other trigger, for
    /// when nothing is currently being arbitrated (the friendship snapshot resolves
    /// to zero buddies on a later foreground or `revealSignal` update, with no
    /// capture in flight). Uses `deferredSoloPaywallDate` — the exact capture day a
    /// milestone deferred this offer for — when one is pending, falling back to
    /// today otherwise; see that property's write site for why "today" is not
    /// always the right day to re-ask against.
    private func resolveSoloPaywall(services: AppServices) {
        guard canPresentAutomaticMoment else { return }
        // A capture is currently being arbitrated — that path owns this decision so
        // a milestone can still outrank the paywall; this resolver only ever handles
        // the case where there is nothing else in flight to arbitrate against.
        guard postCaptureArming == nil else { return }

        prepareSoloPaywallState(for: services.currentUid)
        let evaluationDate = deferredSoloPaywallDate ?? services.clock.today()
        let verdict = SoloMorningPaywallPolicy.evaluate(
            entitlementStatus: services.entitlements.status,
            reading: revealSignal.reading,
            completedCaptureCount: LocalDefaults.completedCaptureCount,
            captureLocalDate: evaluationDate,
            lastPromptedCaptureCount: LocalDefaults.lastSoloPaywallPromptCaptureCount,
            lastPromptedLocalDate: LocalDefaults.lastSoloPaywallPromptLocalDate.flatMap(LocalDate.init(docID:)),
            snoozedUntil: LocalDefaults.soloPaywallSnoozedUntil,
            now: Date()
        )
        // Only a conclusive answer consumes the deferral — `.undetermined` means the
        // friendship snapshot for `evaluationDate` still hasn't landed, and the next
        // re-ask must keep matching against the original capture day, not whatever
        // "today" has since become.
        guard verdict != .undetermined else { return }
        deferredSoloPaywallDate = nil
        guard verdict == .present else { return }

        presentPaywall(from: .soloMorning(captureCount: LocalDefaults.completedCaptureCount))
    }

    /// Mirrors `prepareAutomaticPaywallState` but is deliberately a separate function
    /// with separate storage, so milestone bookkeeping can never perturb paywall state.
    private func prepareMilestoneState(for uid: String) {
        guard LocalDefaults.milestoneAccountID != uid else { return }
        LocalDefaults.resetMilestoneState()
        LocalDefaults.milestoneAccountID = uid
    }

    /// The one-shot write for `.firstUnlock`, and the prompt-cadence bookkeeping for
    /// `.soloMorning`. Every other path that decides a paywall is due but doesn't
    /// present it yet (the milestone branch of `PostCaptureMomentPolicy.decide`)
    /// must leave both untouched, which is exactly what lets the very next re-ask
    /// offer it again.
    private func recordAutomaticPaywallPresentationIfNeeded(services: AppServices) {
        switch paywallEntryPoint {
        case .onboarding:
            LocalDefaults.pendingOnboardingPaywallAfterFirstCapture = false
        case .firstUnlock:
            LocalDefaults.unlockPaywallPresentedAt = Date()
        case .soloMorning(let captureCount):
            LocalDefaults.lastSoloPaywallPromptCaptureCount = captureCount
            LocalDefaults.lastSoloPaywallPromptLocalDate = services.clock.today().docID
        default:
            break
        }
    }

    /// The solo paywall's cadence needs to know about a decline, unlike `.firstUnlock`
    /// (one-shot — the write above is enough). Any exit that is not a successful
    /// purchase reaches here: `PaywallView.purchase`/`restorePurchases` set
    /// `hasResolvedExit` themselves before dismissing, so `onDismissed` never fires
    /// on the path that should reset this instead (see the `onEntitlementGranted`
    /// closure passed to `PaywallView` above).
    private func recordSoloPaywallDismissalIfNeeded(_ reason: PaywallDismissalReason) {
        guard case .soloMorning = paywallEntryPoint else { return }
        let count = LocalDefaults.consecutiveSoloPaywallDismissals + 1
        LocalDefaults.consecutiveSoloPaywallDismissals = count
        LocalDefaults.soloPaywallSnoozedUntil = SoloMorningPaywallPolicy.snoozeUntil(
            afterConsecutiveDismissals: count,
            now: Date()
        )
    }

    private func prepareAutomaticPaywallState(for uid: String) {
        guard LocalDefaults.automaticPaywallAccountID != uid else { return }
        LocalDefaults.resetAutomaticPaywallState()
        LocalDefaults.automaticPaywallAccountID = uid
    }

    /// Mirrors `prepareMilestoneState`/`prepareAutomaticPaywallState`: scopes the
    /// one-shot presented-flag to an account, kept in its own storage so nothing
    /// unlock-paywall-related can perturb `completedCaptureCount`
    /// (`AppReviewPromptPolicy`) or milestone bookkeeping, and vice versa.
    private func prepareUnlockPaywallState(for uid: String) {
        guard LocalDefaults.unlockPaywallAccountID != uid else { return }
        LocalDefaults.resetUnlockPaywallState()
        LocalDefaults.unlockPaywallAccountID = uid
    }

    /// Mirrors `prepareMilestoneState`/`prepareUnlockPaywallState`: scopes the
    /// cadenced solo-paywall bookkeeping to an account, kept in its own storage so
    /// nothing here can perturb any other automatic prompt's state, and vice versa.
    private func prepareSoloPaywallState(for uid: String) {
        guard LocalDefaults.soloPaywallAccountID != uid else { return }
        LocalDefaults.resetSoloPaywallState()
        LocalDefaults.soloPaywallAccountID = uid
    }

    /// Two independent sources can request "open straight to the camera": the
    /// AlarmKit intent (persisted flag, iOS 26+) and a tapped local notification
    /// (`AppRouter.pendingRoute`, iOS 17–25 fallback — see `NotificationRouter`).
    /// Both are consumed by checking their *current* value here, not by reacting to
    /// a change in the value itself: on a cold launch from a notification tap, the
    /// value is already set before this view — and its `.onChange`/`.onAppear`
    /// hooks — ever exist, since `refreshDestination` awaits a network call before
    /// `destination` becomes `.today`. A plain `.onChange(of:)` on the flag would
    /// only fire for a transition it was already attached to observe, silently
    /// missing that already-set value (see dev-notes for how this was found).
    /// Re-checking the current value from every relevant lifecycle hook — appear,
    /// scenePhase becoming active, and destination changing — closes that gap.
    private func consumePendingCameraRequestIfNeeded() {
        guard destination == .today, let services = appServices,
              presentations.isAvailable, homeDestination == nil, cameraRouteTask == nil else { return }
        let wantsCameraFromNotification = router.pendingRoute == .camera
        let wantsCameraFromAlarm = LocalDefaults.openCameraAfterMorningAlarm
        let wantsCameraFromOnboarding = LocalDefaults.openCameraAfterOnboarding
        guard wantsCameraFromNotification || wantsCameraFromAlarm || wantsCameraFromOnboarding else { return }

        cameraRouteTask = Task {
            defer { cameraRouteTask = nil }
            // Both routes can fire after the day's post already exists — a queued
            // notification tap opened late, or the AlarmKit flag surviving a launch
            // that happens after a capture from a different trigger. `TodayView`'s
            // own capture button is already gated on this same check; opening the
            // camera here unconditionally let a second same-day capture reach
            // `PostPublisher.publish` at all, which is what let a post document and
            // its queued upload point at two different images (see `UploadQueue`).
            let today = services.clock.today()
            // Alarm and first-run capture must work without a network read. A
            // locally committed post is the truth that ends a Photo Mission;
            // server conflict handling remains inside PostPublisher.
            if (wantsCameraFromAlarm || wantsCameraFromOnboarding),
               LocalDefaults.lastCapturedLocalDateID != today.docID {
                guard !Task.isCancelled, presentations.isAvailable, homeDestination == nil,
                      services.clock.today() == today,
                      appServices?.currentUid == services.currentUid else { return }
                if wantsCameraFromAlarm { LocalDefaults.openCameraAfterMorningAlarm = false }
                if wantsCameraFromOnboarding { LocalDefaults.openCameraAfterOnboarding = false }
                showCamera = true
                return
            }
            switch await firstValue(from: services.postRepository.observePost(uid: services.currentUid, localDate: today)) {
            case .value(nil):
                guard !Task.isCancelled, presentations.isAvailable, homeDestination == nil,
                      services.clock.today() == today,
                      appServices?.currentUid == services.currentUid else { return }
                if wantsCameraFromNotification { router.pendingRoute = nil }
                if wantsCameraFromAlarm { LocalDefaults.openCameraAfterMorningAlarm = false }
                if wantsCameraFromOnboarding { LocalDefaults.openCameraAfterOnboarding = false }
                homeDestination = nil
                showCamera = true
            case .value(.some):
                // This is a stale notification/Island tap after a completed
                // capture. Consume it rather than preserving a route that can
                // never become valid again, and clear both notification systems.
                if wantsCameraFromNotification { router.pendingRoute = nil }
                if wantsCameraFromAlarm { LocalDefaults.openCameraAfterMorningAlarm = false }
                if wantsCameraFromOnboarding { LocalDefaults.openCameraAfterOnboarding = false }
                await MorningRitualCoordinator.captureCompleted(localDate: today)
            case .unavailable, .none:
                // Preserve the pending route only for a later foreground retry.
                // A failed read must never be used as permission to capture again.
                return
            }
        }
    }

    /// Mirrors `consumePendingCameraRequestIfNeeded()`'s multi-hook re-check pattern —
    /// see that function's doc comment for the exact failure it exists to avoid. A
    /// plain `.onChange(of: router.pendingBuddyRevealRoute)` would silently miss a
    /// cold launch from a tapped buddy-post notification: the flag is already `true`
    /// before this view (and its `.onChange`/`.onAppear` hooks) exist, since
    /// `refreshDestination` awaits a network call before `destination` becomes
    /// `.today`. Re-checking the current value from every relevant lifecycle hook —
    /// appear, scenePhase becoming active, destination changing, and this view's own
    /// `.task` — closes that gap the same way it does for the camera route.
    private func consumePendingBuddyRevealIfNeeded() {
        guard destination == .today, router.pendingBuddyRevealRoute else { return }
        router.pendingBuddyRevealRoute = false
        // This notification historically selected the Today tab. Pop a contextual
        // destination back to the same daily root before refreshing the only
        // server-authoritative reveal reader; never infer a reveal from this route.
        homeDestination = nil
        buddyRefreshToken += 1
    }

    /// Retains the UI-audit/deep-launch compatibility flag from the former tab
    /// shell. It is deliberately one-shot so a body/lifecycle re-evaluation can
    /// never pull a person back into the archive after they navigate elsewhere.
    private func openInitialHomeRouteIfNeeded() {
        guard !hasHandledInitialHomeRoute else { return }
        hasHandledInitialHomeRoute = true
        guard ProcessInfo.processInfo.arguments.contains("-SkyGridLaunchGrid") else { return }
        homeDestination = .archive
    }

    /// The single entry point every lifecycle hook and modal-dismissal callback calls
    /// to re-ask all three pending-presentation questions. A pending invite tap
    /// outranks a derived celebration — it's a deliberate user action — so it
    /// resolves first; the other two are independently guarded and safe to call in
    /// either order. Each resolver no-ops immediately if its own preconditions
    /// aren't met, so calling all three from every site is cheap and never stacks
    /// two presentations at once.
    private func resolvePendingPresentations(services: AppServices) {
        guard destination == .today, scenePhase == .active,
              presentations.isAvailable, homeDestination == nil else { return }
        if let pendingReward {
            // The flag is written only once the coordinator has actually accepted
            // the presentation — see `armDailyReward` for why it is not written at
            // arming time. Dropping the moment on a refused present would lose the
            // celebration outright.
            guard presentations.present(.reward(pendingReward)) else { return }
            LocalDefaults.lastRewardPlayedLocalDate = pendingReward.localDate.docID
            PendingRewardStore.standard.clear()
            self.pendingReward = nil
            return
        }
        resolveOnboardingPaywall(services: services)
        resolvePendingInvite()
        resolvePostCaptureMoment(services: services)
        resolveFirstUnlockPaywall(services: services)
        resolveSoloPaywall(services: services)
    }

    /// Surfaces a Universal-Link-tapped invite once nothing else is claiming the
    /// screen. Called only via `resolvePendingPresentations` — kept as a separate
    /// function because an invite tap is a deliberate user action, not a derived
    /// celebration, and must never be silently dropped by `PostCaptureMomentPolicy`'s
    /// arming/backstop machinery.
    private func resolveOnboardingPaywall(services: AppServices) {
        guard LocalDefaults.pendingOnboardingPaywallAfterFirstCapture,
              LocalDefaults.lastCapturedLocalDateID == services.clock.today().docID,
              canPresentAutomaticMoment else { return }
        // The first real sky and its reward are the onboarding value moment. It
        // owns this capture's follow-up slot so no second automatic prompt stacks.
        consumePostCaptureArming()
        presentPaywall(from: .onboarding(
            profile: LocalDefaults.personalizationProfile,
            wakeGoalMinutes: LocalDefaults.wakeGoalMinutes
        ))
    }

    private func resolvePendingInvite() {
        guard destination == .today,
              canPresentAutomaticMoment,
              let code = router.pendingInviteCode
        else { return }
        inviteMoment = code
    }

    private var canPresentAutomaticMoment: Bool {
        presentations.isAvailable && pendingReward == nil && homeDestination == nil && scenePhase == .active
    }

    private func presentationDidDismiss(services: AppServices) {
        let dismissed = presentations.didDismiss()
        if case .invite(let code) = dismissed, router.pendingInviteCode == code {
            router.consumePendingInvite()
        }
        resolvePendingPresentations(services: services)
        consumePendingCameraRequestIfNeeded()
    }

    private func firstValue<T: Sendable>(from stream: AsyncStream<T>) async -> T? {
        for await value in stream { return value }
        return nil
    }

    /// The only start path for the morning-ritual Live Activity on iOS 17–25
    /// (AlarmKit's `stopIntent` covers iOS 26+ in the background), and on every
    /// OS version the safety net that clears a stale or yesterday's leftover
    /// card. Cheap and idempotent, so calling it from every foreground moment is
    /// safe — see `MorningRitualPolicy`.
    private func reconcileMorningRitual(services: AppServices) async {
        guard !isReconcilingRitual else { return }
        isReconcilingRitual = true
        defer { isReconcilingRitual = false }
        let today = services.clock.today()
        guard case .value(let post)? = await firstValue(from: services.postRepository.observePost(uid: services.currentUid, localDate: today)) else {
            return
        }
        let hasPostToday = post != nil
        await MorningRitualCoordinator.reconcile(
            today: today,
            hasPostToday: hasPostToday,
            now: services.clock.now,
            timeZone: services.clock.timeZone
        )
    }
}

private enum HomeDestination: Hashable, Identifiable {
    case archive
    case buddies
    case settings

    var id: Self { self }
}

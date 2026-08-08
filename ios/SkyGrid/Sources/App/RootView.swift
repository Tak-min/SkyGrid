import Combine
import SwiftUI

struct RootView: View {
    @Environment(\.appServices) private var appServices
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @State private var destination: LaunchDestination = .onboarding
    @State private var showCamera = false
    @State private var showPaywall = false
    @State private var paywallEntryPoint: PaywallEntryPoint = .home
    @State private var pendingAutomaticPaywall: PendingAutomaticPaywall?
    @State private var automaticPaywallPresentationLocalDate: LocalDate?
    @State private var observedLocalDate: LocalDate?
    /// Receives the streak from `TodayViewModel` — the only thing that computes it.
    /// RootView owns post-capture arbitration but holds no reference to that view
    /// model (`TodayView` captures it as `@State`), so the value is published up here
    /// rather than recomputed, which would be a second source of truth.
    @State private var streakSignal = StreakSignal()
    @State private var postCaptureArming: PostCaptureArming?
    @State private var milestoneMoment: MilestoneMoment?
    @State private var selectedTab: HomeTab = ProcessInfo.processInfo.arguments.contains("-SkyGridLaunchGrid") ? .grid : .today
    let onAccountDeleted: () -> Void

    var body: some View {
        Group {
            if let services = appServices {
                content(services: services)
                    .task(id: services.currentUid) {
                        refreshObservedLocalDate(services: services)
                        await services.entitlements.refresh()
                        await refreshDestination(services: services)
                    }
                    .onAppear {
                        refreshObservedLocalDate(services: services)
                        consumePendingCameraRequestIfNeeded()
                        Task { await reconcileMorningRitual(services: services) }
                    }
                    .onChange(of: scenePhase) { _, phase in
                        guard phase == .active else { return }
                        refreshObservedLocalDate(services: services)
                        consumePendingCameraRequestIfNeeded()
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
                    .onChange(of: destination) { _, _ in
                        consumePendingCameraRequestIfNeeded()
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
            OnboardingCoordinatorView(purchases: services.purchases, entitlements: services.entitlements) {
                Task { await refreshDestination(services: services) }
            }
        case .today:
            todayFlow(services: services)
        }
    }

    @ViewBuilder
    private func todayFlow(services: AppServices) -> some View {
        let today = observedLocalDate ?? services.clock.today()
        NavigationStack {
            TabView(selection: $selectedTab) {
                TodayView(
                    viewModel: TodayViewModel(
                        uid: services.currentUid,
                        postRepository: services.postRepository,
                        userRepository: services.userRepository,
                        friendRepository: services.friendRepository,
                        uploadQueue: services.uploadQueue,
                        orphanedPostRecovery: services.orphanedPostRecovery,
                        clock: services.clock,
                        streakSignal: streakSignal
                    ),
                    imageFetching: services.imageFetching,
                    observedDate: today,
                    onOpenCamera: { showCamera = true },
                    subscriptionPlan: services.entitlements.plan,
                    onOpenPaywall: { presentPaywall(from: .home) },
                    onOpenBuddies: { selectedTab = .buddies }
                )
                .tag(HomeTab.today)
                .tabItem { Label("Today", systemImage: "sun.horizon") }

                SkyGridArchiveTab(
                    uid: services.currentUid,
                    currentYear: services.clock.today().year,
                    postRepository: services.postRepository,
                    imageFetching: services.imageFetching,
                    isPro: services.entitlements.isPro,
                    today: services.clock.today(),
                    onUpgrade: { presentPaywall(from: .archive) }
                )
                .tag(HomeTab.grid)
                .tabItem { Label("Sky Grid", systemImage: "square.grid.3x3.fill") }

                BuddiesView(
                    uid: services.currentUid,
                    friendRepository: services.friendRepository,
                    userRepository: services.userRepository,
                    contentSafetyRepository: services.contentSafetyRepository
                )
                .tag(HomeTab.buddies)
                .tabItem { Label("Buddies", systemImage: "person.2.fill") }
            }
            .tint(SGT.ink)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(
                            uid: services.currentUid,
                            accountDeletionService: services.accountDeletionService,
                            friendRepository: services.friendRepository,
                            userRepository: services.userRepository,
                            purchases: services.purchases,
                            entitlements: services.entitlements,
                            onAccountDeleted: onAccountDeleted
                        )
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Open settings")
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: {
            // Source order *is* the priority order: the paywall gets first refusal on
            // the capture, and only what it declined can become a milestone.
            presentPendingAutomaticPaywallIfNeeded()
            resolvePostCaptureMoment()
        }) {
            cameraSheet(services: services)
        }
        .fullScreenCover(item: $milestoneMoment) { moment in
            MilestoneView(moment: moment, onDone: { milestoneMoment = nil })
        }
        .onChange(of: streakSignal.reading) { _, _ in
            // The other half of the resolution: the streak usually lands after the
            // camera is gone, so whichever event is second finds the arming intact.
            resolvePostCaptureMoment()
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            // A capture can be armed and still unresolved when the user opens the
            // paywall *manually* (plan badge, archive upgrade). While it is up,
            // `resolvePostCaptureMoment` defers, and `StreakSignal.record` no-ops on
            // an unchanged reading — so without this, nothing would ever ask again
            // and an earned milestone would be silently dropped. Automatic paywalls
            // are unaffected: they clear the arming when they claim the capture.
            //
            // This recovers the quick-dismissal case only. A paywall session longer
            // than `armingLifetime` still expires the arming, and that is the wanted
            // outcome: a celebration arriving after a minute inside a purchase flow
            // no longer reads as caused by the capture.
            resolvePostCaptureMoment()
        }) {
            PaywallView(
                purchases: services.purchases,
                entryPoint: paywallEntryPoint,
                onEntitlementGranted: {
                    await services.entitlements.refresh()
                    LocalDefaults.consecutiveAutomaticPaywallDismissals = 0
                    LocalDefaults.automaticPaywallSnoozedUntil = nil
                },
                onPresented: recordAutomaticPaywallPresentationIfNeeded,
                onDismissed: recordAutomaticPaywallDismissalIfNeeded
            )
        }
        .task { consumePendingCameraRequestIfNeeded() }
    }

    private func cameraSheet(services: AppServices) -> some View {
        let cameraSource = services.cameraSourceFactory()
        return CameraView(
            viewModel: CameraViewModel(
                ownerUid: services.currentUid,
                cameraSource: cameraSource,
                clock: services.clock,
                wakeGoal: WakeGoal(minutesAfterMidnight: LocalDefaults.wakeGoalMinutes)
            ),
            liveSession: cameraSource.session,
            onDismiss: { showCamera = false },
            onConfirmed: { draft in
                try await services.postPublisher.publish(draft)
                await MorningRitualCoordinator.captureCompleted(localDate: draft.localDate)
                await considerAutomaticPaywall(afterCompletedCapture: draft, services: services)
                showCamera = false
            }
        )
    }

    private func refreshDestination(services: AppServices) async {
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
        paywallEntryPoint = entryPoint
        showPaywall = true
    }

    /// A successful capture means the Firestore record and durable local upload
    /// outbox were both written. The remote image upload can finish later, so this
    /// deliberately measures completed captures rather than uploaded photos.
    private func considerAutomaticPaywall(afterCompletedCapture draft: PostDraft, services: AppServices) async {
        prepareAutomaticPaywallState(for: draft.ownerUid)
        guard LocalDefaults.lastCompletedCaptureLocalDate != draft.localDate.docID else { return }

        LocalDefaults.lastCompletedCaptureLocalDate = draft.localDate.docID
        LocalDefaults.completedCaptureCount += 1
        let count = LocalDefaults.completedCaptureCount
        await services.entitlements.refresh()
        let now = Date()
        guard AutomaticPaywallPresentationPolicy.shouldPresent(
            entitlementStatus: services.entitlements.status,
            completedCaptureCount: count,
            lastPromptedCaptureCount: LocalDefaults.lastAutomaticPaywallPromptCaptureCount,
            lastPromptedLocalDate: LocalDefaults.lastAutomaticPaywallPromptLocalDate.flatMap(LocalDate.init(docID:)),
            captureLocalDate: draft.localDate,
            snoozedUntil: LocalDefaults.automaticPaywallSnoozedUntil,
            now: now
        ) else {
            // The paywall isn't showing on this capture. Hand the moment to the
            // lower-priority queue (milestone, then review) rather than deciding it
            // here — the streak that answers "is this a milestone?" is computed by
            // Today's history listener and has not necessarily arrived yet.
            armPostCaptureMoment(
                localDate: draft.localDate,
                completedCaptureCount: count,
                uid: draft.ownerUid
            )
            return
        }

        // fullScreenCover(onDismiss:) presents this only after the camera is
        // actually gone; unlike a timed delay it cannot race iOS modal dismissal.
        pendingAutomaticPaywall = PendingAutomaticPaywall(
            entryPoint: .ritualMilestone(captureCount: count),
            localDate: draft.localDate
        )
        // The paywall took this capture. Nothing lower-priority may also claim it.
        postCaptureArming = nil
    }

    /// Records that a capture completed without the paywall claiming it, so the
    /// milestone/review question can be answered once the streak arrives.
    private func armPostCaptureMoment(localDate: LocalDate, completedCaptureCount: Int, uid: String) {
        prepareMilestoneState(for: uid)
        postCaptureArming = PostCaptureArming(
            localDate: localDate,
            completedCaptureCount: completedCaptureCount,
            didPresentPaywall: false,
            armedAt: Date()
        )
        resolvePostCaptureMoment()
    }

    /// Re-asks `PostCaptureMomentPolicy` whenever something that could change its
    /// answer happened. Safe to call repeatedly: the arming is consumed exactly once,
    /// and an unanswerable question leaves it armed for the next event.
    private func resolvePostCaptureMoment() {
        guard let arming = postCaptureArming else { return }
        // Never stack a celebration on top of another modal — and never resolve while
        // the paywall is still pending, which would invert the priority order.
        guard !showCamera, !showPaywall, pendingAutomaticPaywall == nil, milestoneMoment == nil else { return }

        switch PostCaptureMomentPolicy.decide(
            arming: arming,
            reading: streakSignal.reading,
            lastCelebratedMilestone: LocalDefaults.lastCelebratedStreakMilestone,
            hasRequestedAppReview: LocalDefaults.hasRequestedAppReview,
            now: Date()
        ) {
        case .awaitingStreak:
            return
        case .paywall, .none:
            postCaptureArming = nil
        case .milestone(let milestone):
            guard case .observed(_, _, let post?) = streakSignal.reading else {
                // `decide` already proved this, but reading the post back out is what
                // actually builds the card — never force-unwrap that proof.
                return
            }
            // Persisted *before* presenting, so a re-entrant resolution or a crash
            // mid-presentation can never produce the same celebration twice.
            LocalDefaults.lastCelebratedStreakMilestone = milestone.streak
            postCaptureArming = nil
            milestoneMoment = MilestoneMoment(
                milestone: milestone,
                post: post,
                photo: localPhoto(for: post),
                handle: LocalDefaults.handle.flatMap(Handle.init(raw:))
            )
        case .reviewPrompt:
            postCaptureArming = nil
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

    /// Mirrors `prepareAutomaticPaywallState` but is deliberately a separate function
    /// with separate storage, so milestone bookkeeping can never perturb paywall state.
    private func prepareMilestoneState(for uid: String) {
        guard LocalDefaults.milestoneAccountID != uid else { return }
        LocalDefaults.resetMilestoneState()
        LocalDefaults.milestoneAccountID = uid
    }

    private func presentPendingAutomaticPaywallIfNeeded() {
        guard let pendingAutomaticPaywall, !showPaywall else { return }
        automaticPaywallPresentationLocalDate = pendingAutomaticPaywall.localDate
        self.pendingAutomaticPaywall = nil
        presentPaywall(from: pendingAutomaticPaywall.entryPoint)
    }

    private func recordAutomaticPaywallPresentationIfNeeded() {
        guard paywallEntryPoint.isAutomaticReminder,
              let localDate = automaticPaywallPresentationLocalDate
        else { return }
        LocalDefaults.lastAutomaticPaywallPromptCaptureCount = LocalDefaults.completedCaptureCount
        LocalDefaults.lastAutomaticPaywallPromptLocalDate = localDate.docID
        automaticPaywallPresentationLocalDate = nil
    }

    private func recordAutomaticPaywallDismissalIfNeeded(_ reason: PaywallDismissalReason) {
        guard paywallEntryPoint.isAutomaticReminder else { return }
        LocalDefaults.consecutiveAutomaticPaywallDismissals += 1
        LocalDefaults.automaticPaywallSnoozedUntil = AutomaticPaywallPresentationPolicy.snoozeUntil(
            afterConsecutiveDismissals: LocalDefaults.consecutiveAutomaticPaywallDismissals,
            now: Date()
        )
    }

    private func prepareAutomaticPaywallState(for uid: String) {
        guard LocalDefaults.automaticPaywallAccountID != uid else { return }
        LocalDefaults.resetAutomaticPaywallState()
        LocalDefaults.automaticPaywallAccountID = uid
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
        guard destination == .today, let services = appServices else { return }
        let wantsCameraFromNotification = router.pendingRoute == .camera
        let wantsCameraFromAlarm = LocalDefaults.openCameraAfterMorningAlarm
        guard wantsCameraFromNotification || wantsCameraFromAlarm else { return }

        Task {
            // Both routes can fire after the day's post already exists — a queued
            // notification tap opened late, or the AlarmKit flag surviving a launch
            // that happens after a capture from a different trigger. `TodayView`'s
            // own capture button is already gated on this same check; opening the
            // camera here unconditionally let a second same-day capture reach
            // `PostPublisher.publish` at all, which is what let a post document and
            // its queued upload point at two different images (see `UploadQueue`).
            let today = services.clock.today()
            switch await firstValue(from: services.postRepository.observePost(uid: services.currentUid, localDate: today)) {
            case .value(nil):
                if wantsCameraFromNotification { router.pendingRoute = nil }
                if wantsCameraFromAlarm { LocalDefaults.openCameraAfterMorningAlarm = false }
                selectedTab = .today
                showCamera = true
            case .value(.some):
                // This is a stale notification/Island tap after a completed
                // capture. Consume it rather than preserving a route that can
                // never become valid again, and clear both notification systems.
                if wantsCameraFromNotification { router.pendingRoute = nil }
                if wantsCameraFromAlarm { LocalDefaults.openCameraAfterMorningAlarm = false }
                await MorningRitualCoordinator.captureCompleted(localDate: today)
            case .unavailable, .none:
                // Preserve the pending route only for a later foreground retry.
                // A failed read must never be used as permission to capture again.
                return
            }
        }
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

private enum HomeTab: Hashable {
    case today
    case grid
    case buddies
}

private struct PendingAutomaticPaywall {
    let entryPoint: PaywallEntryPoint
    let localDate: LocalDate
}

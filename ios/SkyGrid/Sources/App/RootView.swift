import SwiftUI

struct RootView: View {
    @Environment(\.appServices) private var appServices
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @State private var destination: LaunchDestination = .onboarding
    @State private var showCamera = false
    @State private var showPaywall = false
    @State private var paywallEntryPoint: PaywallEntryPoint = .home
    @State private var pendingAutomaticPaywall: PendingAutomaticPaywall?
    @State private var automaticPaywallPresentationLocalDate: LocalDate?
    @State private var selectedTab: HomeTab = ProcessInfo.processInfo.arguments.contains("-SkyGridLaunchGrid") ? .grid : .today
    let onAccountDeleted: () -> Void

    var body: some View {
        Group {
            if let services = appServices {
                content(services: services)
                    .task(id: services.currentUid) {
                        await services.entitlements.refresh()
                        await refreshDestination(services: services)
                    }
                    .onAppear {
                        consumePendingCameraRequestIfNeeded()
                        Task { await reconcileMorningRitual(services: services) }
                    }
                    .onChange(of: scenePhase) { _, phase in
                        guard phase == .active else { return }
                        consumePendingCameraRequestIfNeeded()
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
                        clock: services.clock
                    ),
                    imageFetching: services.imageFetching,
                    onOpenCamera: { showCamera = true },
                    subscriptionPlan: services.entitlements.plan,
                    onOpenPaywall: { presentPaywall(from: .home) }
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
        .fullScreenCover(isPresented: $showCamera, onDismiss: presentPendingAutomaticPaywallIfNeeded) {
            cameraSheet(services: services)
        }
        .sheet(isPresented: $showPaywall) {
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
        ) else { return }

        // fullScreenCover(onDismiss:) presents this only after the camera is
        // actually gone; unlike a timed delay it cannot race iOS modal dismissal.
        pendingAutomaticPaywall = PendingAutomaticPaywall(
            entryPoint: .ritualMilestone(captureCount: count),
            localDate: draft.localDate
        )
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
            let existingPost = await firstValue(from: services.postRepository.observePost(uid: services.currentUid, localDate: today)).flatMap { $0 }

            if wantsCameraFromNotification { router.pendingRoute = nil }
            if wantsCameraFromAlarm { LocalDefaults.openCameraAfterMorningAlarm = false }
            guard existingPost == nil else { return }

            selectedTab = .today
            showCamera = true
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
        let hasPostToday = await firstValue(from: services.postRepository.observePost(uid: services.currentUid, localDate: today)).flatMap { $0 } != nil
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

import SwiftUI

struct RootView: View {
    @Environment(\.appServices) private var appServices
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @State private var destination: LaunchDestination = .onboarding
    @State private var showCamera = false
    @State private var showPaywall = false
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
                    .onAppear { consumeAlarmCameraRequestIfNeeded() }
                    .onChange(of: scenePhase) { _, phase in
                        guard phase == .active else { return }
                        consumeAlarmCameraRequestIfNeeded()
                    }
                    .onChange(of: destination) { _, _ in
                        consumeAlarmCameraRequestIfNeeded()
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
                        clock: services.clock
                    ),
                    imageFetching: services.imageFetching,
                    onOpenCamera: { showCamera = true }
                )
                .tag(HomeTab.today)
                .tabItem { Label("Today", systemImage: "sun.horizon") }

                GridArchiveView(
                    uid: services.currentUid,
                    year: services.clock.today().year,
                    postRepository: services.postRepository,
                    isPro: services.entitlements.isPro,
                    today: services.clock.today(),
                    onUpgrade: { showPaywall = true }
                )
                .tag(HomeTab.grid)
                .tabItem { Label("Sky Grid", systemImage: "square.grid.3x3.fill") }
            }
            .tint(SGT.ink)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        BuddiesView(
                            uid: services.currentUid,
                            friendRepository: services.friendRepository,
                            userRepository: services.userRepository,
                            contentSafetyRepository: services.contentSafetyRepository
                        )
                    } label: {
                        Image(systemName: "person.2")
                    }
                    .accessibilityLabel("Open buddies")

                    NavigationLink {
                        SettingsView(
                            uid: services.currentUid,
                            accountDeletionService: services.accountDeletionService,
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
        .fullScreenCover(isPresented: $showCamera) {
            cameraSheet(services: services)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                purchases: services.purchases,
                entryPoint: .archive,
                onEntitlementGranted: { Task { await services.entitlements.refresh() } }
            )
        }
        .onChange(of: router.pendingRoute) { _, newValue in
            guard newValue == .camera else { return }
            selectedTab = .today
            showCamera = true
            router.pendingRoute = nil
        }
        .task { consumeAlarmCameraRequestIfNeeded() }
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
            onConfirmed: { draft in
                try await services.postPublisher.publish(draft)
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

    /// `OpenMorningCameraIntent` persists its request before the system brings the
    /// app forward. Consume only once Today exists so a cold launch never flashes
    /// the home UI before the full-screen camera cover appears.
    private func consumeAlarmCameraRequestIfNeeded() {
        guard destination == .today, LocalDefaults.openCameraAfterMorningAlarm else { return }
        LocalDefaults.openCameraAfterMorningAlarm = false
        selectedTab = .today
        showCamera = true
    }
}

private enum HomeTab: Hashable {
    case today
    case grid
}

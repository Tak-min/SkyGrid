import SwiftUI
import UIKit

@main
struct SkyGridApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var startup = AppStartupController()

    var body: some Scene {
        WindowGroup {
            Group {
#if DEBUG
                if let scenario = UIAuditScenario.current {
                    UIAuditRoot(scenario: scenario)
                } else {
                    AppStartupView(startup: startup, appRouter: appDelegate.appRouter)
                }
#else
                AppStartupView(startup: startup, appRouter: appDelegate.appRouter)
#endif
            }
            .onOpenURL { url in
                appDelegate.appRouter.handle(url: url)
            }
        }
    }
}

#if DEBUG
/// A local-only route for simulator screenshots and UI regression tests. It never
/// talks to Firebase, RevenueCat, or a real person’s photo archive, and ships out
/// of Release builds entirely.
private enum UIAuditScenario: String {
    case onboarding
    case today
    case todayUnavailable = "today-unavailable"
    case grid
    case gridUnavailable = "grid-unavailable"
    case buddies
    case buddiesUnavailable = "buddies-unavailable"
    case buddiesProfileUnavailable = "buddies-profile-unavailable"
    case buddiesNoHandle = "buddies-no-handle"
    case buddiesRequestFlow = "buddies-request-flow"
    case paywall
    case paywallPlan = "paywall-plan"
    case settings
    case settingsBlockedUnavailable = "settings-blocked-unavailable"
    case cameraReview = "camera-review"
    case cameraFailure = "camera-failure"
    case shareYear = "share-year"
    case shareMorning = "share-morning"
    case liveActivity = "live-activity"
    case milestone
    case milestoneDayOne = "milestone-day-one"

    static var current: Self? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-SkyGridUIAudit"),
              let index = arguments.firstIndex(of: "-SkyGridUIAuditScenario"),
              arguments.indices.contains(index + 1)
        else { return nil }
        return Self(rawValue: arguments[index + 1])
    }
}

@MainActor
private struct UIAuditRoot: View {
    let scenario: UIAuditScenario
    @State private var selectedTab: UIAuditTab
    @State private var auditEntitlements: EntitlementStore
    private let auditPostRepository: UIAuditPostRepository
    private let auditFriendRepository: UIAuditFriendRepository
    private let auditUserRepository: UIAuditUserRepository

    init(scenario: UIAuditScenario) {
        self.scenario = scenario
        _selectedTab = State(initialValue: UIAuditTab(scenario: scenario))
        _auditEntitlements = State(initialValue: EntitlementStore(purchases: UIAuditPurchases()))
        auditPostRepository = UIAuditPostRepository(
            posts: UIAuditData.posts,
            failsFirstPostsRead: scenario == .gridUnavailable
        )
        auditFriendRepository = UIAuditFriendRepository(
            failsFirstRead: scenario == .buddiesUnavailable,
            failsFirstBlockedRead: scenario == .settingsBlockedUnavailable,
            includesRequestFlow: scenario == .buddiesRequestFlow
        )
        auditUserRepository = UIAuditUserRepository(
            failsFirstCurrentProfileRead: scenario == .buddiesProfileUnavailable,
            currentHasHandle: scenario != .buddiesNoHandle
        )
    }

    var body: some View {
        if scenario == .onboarding {
            OnboardingCoordinatorView(
                purchases: UIAuditPurchases(),
                entitlements: auditEntitlements,
                onFinished: {}
            )
        } else if scenario == .paywall {
            PaywallView(
                purchases: UIAuditPurchases(),
                entryPoint: .ritualMilestone(captureCount: 10),
                onEntitlementGranted: {},
                onDismissed: { _ in }
            )
        } else if scenario == .paywallPlan {
            // The App Store subscription review screenshot needs all three prices
            // visible without walking the funnel by hand — see F3 in the paywall
            // redesign dev-note.
            PaywallView(
                purchases: UIAuditPurchases(),
                entryPoint: .settings,
                initialStep: .plan,
                onEntitlementGranted: {},
                onDismissed: { _ in }
            )
        } else if scenario == .settings || scenario == .settingsBlockedUnavailable {
            NavigationStack {
                SettingsView(
                    uid: UIAuditData.currentUID,
                    accountDeletionService: UIAuditAccountDeletionService(),
                    friendRepository: auditFriendRepository,
                    userRepository: auditUserRepository,
                    purchases: UIAuditPurchases(),
                    entitlements: auditEntitlements,
                    onAccountDeleted: {}
                )
            }
        } else if scenario == .liveActivity {
            LiveActivityAuditView()
        } else if scenario == .shareYear {
            ShareCardAuditView { SkyGridExportView(
                year: 2026,
                postedDates: Set(UIAuditData.postsByDate.keys),
                photos: UIAuditData.thumbnails,
                handle: Handle(raw: "morning_auditor")
            ) }
        } else if scenario == .shareMorning {
            ShareCardAuditView { MorningCardExportView(
                post: UIAuditData.posts[17],
                photo: UIAuditData.thumbnails[UIAuditData.posts[17].localDate],
                streak: 18,
                handle: Handle(raw: "morning_auditor")
            ) }
        } else if scenario == .milestone || scenario == .milestoneDayOne {
            let isDayOne = scenario == .milestoneDayOne
            MilestoneView(
                moment: MilestoneMoment(
                    milestone: StreakMilestone(streak: isDayOne ? 1 : 30),
                    post: UIAuditData.posts[17],
                    // Day one deliberately renders without a photo so the sky-colour
                    // degradation path is visually verified too, not just assumed.
                    photo: isDayOne ? nil : UIAuditData.thumbnails[UIAuditData.posts[17].localDate],
                    handle: Handle(raw: "morning_auditor")
                ),
                onDone: {}
            )
        } else if scenario == .cameraReview {
            CameraReviewAuditView()
        } else if scenario == .cameraFailure {
            CameraFailureAuditView()
        } else {
            NavigationStack {
                TabView(selection: $selectedTab) {
                    TodayView(
                        viewModel: scenario == .todayUnavailable
                            ? UIAuditData.recoveringTodayViewModel()
                            : UIAuditData.todayViewModel(),
                        imageFetching: UIAuditImageFetcher(),
                        observedDate: UIAuditData.today,
                        onOpenCamera: {},
                        subscriptionPlan: .free,
                        onOpenPaywall: {},
                        onOpenBuddies: { selectedTab = .buddies }
                    )
                    .tag(UIAuditTab.today)
                    .tabItem { Label("Today", systemImage: "sun.horizon") }

                    Group {
                        if scenario == .gridUnavailable {
                            GridArchiveView(
                                uid: UIAuditData.currentUID,
                                year: 2026,
                                postRepository: auditPostRepository,
                                imageFetching: UIAuditImageFetcher(),
                                isPro: true,
                                today: UIAuditData.today,
                                onUpgrade: {}
                            )
                        } else {
                            UIAuditGridScreen()
                        }
                    }
                        .tag(UIAuditTab.grid)
                        .tabItem { Label("Sky Grid", systemImage: "square.grid.3x3.fill") }

                    BuddiesView(
                        uid: UIAuditData.currentUID,
                        friendRepository: auditFriendRepository,
                        userRepository: auditUserRepository,
                        contentSafetyRepository: UIAuditSafetyRepository()
                    )
                    .tag(UIAuditTab.buddies)
                    .tabItem { Label("Buddies", systemImage: "person.2.fill") }
                }
                .tint(SGT.ink)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Image(systemName: "gearshape")
                            .accessibilityLabel("Open settings")
                    }
                }
            }
        }
    }
}

private enum UIAuditTab: Hashable {
    case today
    case grid
    case buddies

    init(scenario: UIAuditScenario) {
        switch scenario {
        case .onboarding, .today, .todayUnavailable, .paywall, .paywallPlan, .settings, .settingsBlockedUnavailable, .cameraReview, .cameraFailure, .shareYear, .shareMorning, .liveActivity, .milestone, .milestoneDayOne: self = .today
        case .grid, .gridUnavailable: self = .grid
        case .buddies, .buddiesUnavailable, .buddiesProfileUnavailable, .buddiesNoHandle, .buddiesRequestFlow: self = .buddies
        }
    }
}

@MainActor
private struct LiveActivityAuditView: View {
    @State private var result = "Starting Live Activity…"

    var body: some View {
        VStack(spacing: SGSpacing.lg) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 48))
                .foregroundStyle(SGT.ink2)
            Text("Dynamic Island audit")
                .font(SGFont.serifTitle(30))
            Text(result)
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
            Button("Restart Live Activity") {
                Task { await restart() }
            }
            .buttonStyle(SkyPrimaryButtonStyle())
            Button("End Live Activity") {
                Task {
                    await MorningRitualActivity.end(status: .ended)
                    result = "Ended"
                }
            }
            .buttonStyle(SkySecondaryButtonStyle())
        }
        .padding(SGSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGT.background)
        .task { await restart() }
    }

    private func restart() async {
        await MorningRitualActivity.end(status: .ended)
        let startResult = MorningRitualActivity.start(
            localDateID: "ui-audit-live-activity",
            wokeAt: Date()
        )
        switch startResult {
        case .started: result = "Started — leave the app to inspect the Island."
        case .alreadyRunning: result = "Already running"
        case .disabled: result = "Live Activities are disabled in Settings."
        case .failed: result = "ActivityKit rejected the request."
        }
    }
}

@MainActor
private struct UIAuditGridScreen: View {
    @State private var selectedMonth = 7
    @State private var selectedYear = 2026

    var body: some View {
        SkyGridView(
            year: selectedYear,
            posts: UIAuditData.postsByDate,
            thumbnails: UIAuditData.thumbnails,
            selectedMonth: selectedMonth,
            onSelectMonth: { selectedMonth = $0 },
            onSelectPost: { _ in },
            lockedPhotoCount: 0,
            canShare: true,
            onShare: {},
            archiveNotice: "Free keeps your most recent 30 days visible.",
            onUpgrade: {},
            onSelectPreviousYear: selectedYear > 2000 ? { selectedYear -= 1 } : nil,
            onSelectNextYear: selectedYear < 2026 ? { selectedYear += 1 } : nil
        )
    }
}

/// Renders a fixed 1080x1920 export canvas scaled to fit the simulator screen, so a
/// share card can be inspected visually without going through the share sheet.
@MainActor
private struct ShareCardAuditView<Card: View>: View {
    @ViewBuilder let card: () -> Card

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 1080, proxy.size.height / 1920)
            card()
                .frame(width: 1080, height: 1920)
                .scaleEffect(scale, anchor: .center)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .background(Color.black)
    }
}

@MainActor
private enum UIAuditData {
    static let currentUID = "ui-audit-user"
    static let fixedClock = FixedClock(
        now: Date(timeIntervalSince1970: 1_785_380_400),
        timeZone: TimeZone(identifier: "UTC")!
    )
    static let today = fixedClock.today()

    static let posts: [SkyPost] = (Array(1...18) + [28, 29]).map { day in
        SkyPost(
            ownerUid: currentUID,
            localDate: LocalDate(year: 2026, month: 7, day: day),
            capturedAt: fixedClock.now.addingTimeInterval(Double(day - 18) * 24 * 60 * 60),
            uploadedAt: fixedClock.now,
            imagePath: "ui-audit/\(day).jpg",
            thumbPath: "ui-audit/\(day)_thumb.jpg",
            skyColor: SkyColor(uncheckedHex: day.isMultiple(of: 2) ? "#91B6C8" : "#D89B76"),
            minutesFromGoal: -8,
            reactions: [:]
        )
    }

    static let postsByDate = Dictionary(uniqueKeysWithValues: posts.map { ($0.localDate, $0) })
    static let thumbnails = Dictionary(uniqueKeysWithValues: posts.map {
        ($0.localDate, thumbnail(for: $0.skyColor))
    })
    static let postRepository = UIAuditPostRepository(posts: posts)
    static let userRepository = UIAuditUserRepository()
    static let friendRepository = UIAuditFriendRepository()
    static let uploadQueue = UploadQueue(
        modelContainer: LocalStoreContainer.make(inMemory: true),
        uploader: UIAuditImageUploader()
    )
    static let orphanedPostRecovery = UIAuditOrphanedPostRecovery()

    static func todayViewModel() -> TodayViewModel {
        TodayViewModel(
            uid: currentUID,
            postRepository: postRepository,
            userRepository: userRepository,
            friendRepository: friendRepository,
            uploadQueue: uploadQueue,
            orphanedPostRecovery: orphanedPostRecovery,
            clock: fixedClock
        )
    }

    static func recoveringTodayViewModel() -> TodayViewModel {
        TodayViewModel(
            uid: currentUID,
            postRepository: UIAuditPostRepository(posts: posts, failsFirstTodayRead: true),
            userRepository: userRepository,
            friendRepository: friendRepository,
            uploadQueue: uploadQueue,
            orphanedPostRecovery: orphanedPostRecovery,
            clock: fixedClock
        )
    }

    private static func thumbnail(for skyColor: SkyColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96))
        return renderer.image { context in
            let base = UIColor(skyColor.color)
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [base.withAlphaComponent(0.96).cgColor, UIColor.white.withAlphaComponent(0.32).cgColor] as CFArray,
                locations: [0, 1]
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 96, y: 96),
                options: []
            )
        }
    }
}

@MainActor
private final class UIAuditPostRepository: PostRepository {
    private let posts: [SkyPost]
    private let failsFirstTodayRead: Bool
    private let failsFirstPostsRead: Bool
    private var todayObservationCount = 0
    private var postsObservationCount = 0

    init(posts: [SkyPost], failsFirstTodayRead: Bool = false, failsFirstPostsRead: Bool = false) {
        self.posts = posts
        self.failsFirstTodayRead = failsFirstTodayRead
        self.failsFirstPostsRead = failsFirstPostsRead
    }

    func observePost(uid: String, localDate: LocalDate) -> AsyncStream<PostObservation> {
        todayObservationCount += 1
        if failsFirstTodayRead, todayObservationCount == 1 {
            return stream(.unavailable)
        }
        return stream(.value(posts.first { $0.ownerUid == uid && $0.localDate == localDate }))
    }

    func observePosts(uid: String, from: LocalDate, through: LocalDate) -> AsyncStream<PostCollectionObservation> {
        postsObservationCount += 1
        if failsFirstPostsRead, postsObservationCount == 1 {
            return stream(.unavailable)
        }
        return stream(.value(posts.filter { $0.ownerUid == uid && $0.localDate >= from && $0.localDate <= through }))
    }

    func fetchPost(uid: String, localDate: LocalDate) async throws -> SkyPost? {
        posts.first { $0.ownerUid == uid && $0.localDate == localDate }
    }

    func createPost(_ draft: PostDraft) async throws {}
    func deletePost(uid: String, localDate: LocalDate) async throws {}

    private func stream<T: Sendable>(_ value: T) -> AsyncStream<T> {
        return AsyncStream { continuation in
            continuation.yield(value)
            continuation.finish()
        }
    }
}

@MainActor
private final class UIAuditUserRepository: UserRepository {
    private let failsFirstCurrentProfileRead: Bool
    private var currentProfileObservationCount = 0

    private let profiles: [String: UserProfile]

    init(failsFirstCurrentProfileRead: Bool = false, currentHasHandle: Bool = true) {
        self.failsFirstCurrentProfileRead = failsFirstCurrentProfileRead
        profiles = [
            UIAuditData.currentUID: UserProfile(
                uid: UIAuditData.currentUID,
                handle: currentHasHandle ? Handle(raw: "morning_auditor") : nil,
                displayName: "You",
                timezone: "UTC",
                wakeGoalMinutes: 360,
                streakCurrent: 4,
                streakLongest: 8,
                lastPostLocalDate: nil,
                isPro: false
            ),
            "mira": UserProfile(uid: "mira", handle: Handle(raw: "mira_sky"), displayName: "Mira", timezone: "UTC", wakeGoalMinutes: 360, streakCurrent: 3, streakLongest: 5, lastPostLocalDate: nil, isPro: false),
            "ren": UserProfile(uid: "ren", handle: Handle(raw: "ren_wakes"), displayName: "Ren", timezone: "UTC", wakeGoalMinutes: 360, streakCurrent: 7, streakLongest: 12, lastPostLocalDate: nil, isPro: false),
            "luca": UserProfile(uid: "luca", handle: Handle(raw: "luca_sky"), displayName: "Luca", timezone: "UTC", wakeGoalMinutes: 360, streakCurrent: 1, streakLongest: 2, lastPostLocalDate: nil, isPro: false),
            "sora": UserProfile(uid: "sora", handle: Handle(raw: "sora_sky"), displayName: "Sora", timezone: "UTC", wakeGoalMinutes: 360, streakCurrent: 2, streakLongest: 4, lastPostLocalDate: nil, isPro: false),
        ]
    }

    func observeProfile(uid: String) -> AsyncStream<UserProfileObservation> {
        if uid == UIAuditData.currentUID {
            currentProfileObservationCount += 1
        }
        let shouldFail = uid == UIAuditData.currentUID
            && failsFirstCurrentProfileRead
            && currentProfileObservationCount == 1
        return AsyncStream { continuation in
            continuation.yield(shouldFail ? .unavailable : .value(profiles[uid]))
            continuation.finish()
        }
    }

    func createOrUpdateProfile(_ profile: UserProfile) async throws {}
    func claimHandle(_ handle: Handle, for uid: String) async throws {}
    func findUid(forHandle handle: Handle) async throws -> String? {
        profiles.first(where: { $0.value.handle == handle })?.key
    }
}

@MainActor
private final class UIAuditFriendRepository: FriendRepository {
    private let failsFirstRead: Bool
    private let failsFirstBlockedRead: Bool
    private let includesRequestFlow: Bool
    private var observationCount = 0
    private var blockedObservationCount = 0

    init(
        failsFirstRead: Bool = false,
        failsFirstBlockedRead: Bool = false,
        includesRequestFlow: Bool = false
    ) {
        self.failsFirstRead = failsFirstRead
        self.failsFirstBlockedRead = failsFirstBlockedRead
        self.includesRequestFlow = includesRequestFlow
    }

    func observeFriendships(uid: String) -> AsyncStream<FriendshipCollectionObservation> {
        let now = UIAuditData.fixedClock.now
        observationCount += 1
        let shouldFail = failsFirstRead && observationCount == 1
        return AsyncStream { continuation in
            if shouldFail {
                continuation.yield(.unavailable)
                continuation.finish()
                return
            }
            var friendships = [
                Friendship(pairId: PairID.make(uid, "mira"), members: [uid, "mira"], status: .accepted, requestedBy: uid, createdAt: now, blockedBy: []),
                Friendship(pairId: PairID.make(uid, "ren"), members: [uid, "ren"], status: .accepted, requestedBy: "ren", createdAt: now, blockedBy: [])
            ]
            if includesRequestFlow {
                friendships.append(contentsOf: [
                    Friendship(
                        pairId: PairID.make(uid, "luca"),
                        members: [uid, "luca"],
                        status: .pending,
                        requestedBy: "luca",
                        requestedByHandle: Handle(raw: "luca_sky"),
                        recipientHandle: Handle(raw: "morning_auditor"),
                        createdAt: now,
                        blockedBy: []
                    ),
                    Friendship(
                        pairId: PairID.make(uid, "sora"),
                        members: [uid, "sora"],
                        status: .pending,
                        requestedBy: uid,
                        requestedByHandle: Handle(raw: "morning_auditor"),
                        recipientHandle: Handle(raw: "sora_sky"),
                        createdAt: now,
                        blockedBy: []
                    ),
                ])
            }
            continuation.yield(.value(friendships))
            continuation.finish()
        }
    }

    func observeBlockedFriendships(uid: String) -> AsyncStream<BlockedFriendshipCollectionObservation> {
        let now = UIAuditData.fixedClock.now
        blockedObservationCount += 1
        let shouldFail = failsFirstBlockedRead && blockedObservationCount == 1
        return AsyncStream { continuation in
            if shouldFail {
                continuation.yield(.unavailable)
                continuation.finish()
                return
            }
            continuation.yield(.value([
                Friendship(pairId: PairID.make(uid, "kai"), members: [uid, "kai"], status: .accepted, requestedBy: uid, createdAt: now, blockedBy: [uid])
            ]))
            continuation.finish()
        }
    }

    func sendRequest(
        from: String,
        to: String,
        requesterHandle: Handle,
        recipientHandle: Handle
    ) async throws -> FriendRequestResult {
        if includesRequestFlow, to == "luca" { return .incomingRequestExists }
        if to == "mira" || to == "ren" { return .alreadyBuddies }
        return .sent
    }
    func acceptRequest(pairId: String, acceptingUid: String) async throws {}
    func removeFriendship(pairId: String) async throws {}
    func block(ownerUid: String, blockedUid: String) async throws {}
    func unblock(ownerUid: String, blockedUid: String) async throws {}
    func isBlocked(ownerUid: String, otherUid: String) async throws -> Bool { false }
}

private struct UIAuditImageFetcher: ImageFetching {
    func fetchImage(path: String) async throws -> Data {
        throw RepositoryError.network(underlying: "UI audit does not load remote images.")
    }
}

private struct UIAuditImageUploader: ImageUploading {
    func upload(fileURL: URL, to path: String, contentType: String) async throws {}
}

@MainActor
private struct UIAuditOrphanedPostRecovery: OrphanedPostRecovering {
    func evaluate(post: SkyPost, now: Date) async -> TodayPostIntegrity { .intact }
    func recover(post: SkyPost) async throws {}
}

@MainActor
private struct UIAuditSafetyRepository: ContentSafetyRepository {
    func submitConcern(reporterUid: String, subjectUid: String) async throws {}
}

private struct UIAuditAccountDeletionService: AccountDeleting {
    func deleteAccount(uid: String) async throws {
        if ProcessInfo.processInfo.arguments.contains("-SkyGridDelayAccountDeletion") {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }
}

private struct UIAuditPurchases: PurchasesServicing {
    func entitlementStatus() async -> EntitlementStatus { .notSubscribed }

    func fetchPaywall() async throws -> PaywallContent {
        PaywallContent(
            offeringID: "ui-audit",
            products: [
                PurchaseProduct(
                    id: "annual",
                    title: "Sky Grid Pro Annual",
                    priceLabel: "$19.99",
                    periodLabel: "Annual",
                    offeringID: "ui-audit",
                    period: .annual,
                    pricePerMonth: 1.67,
                    pricePerMonthLabel: "$1.67",
                    price: 19.99,
                    billingDescription: "$19.99 per year. Auto-renews unless cancelled."
                ),
                PurchaseProduct(
                    id: "monthly",
                    title: "Sky Grid Pro Monthly",
                    priceLabel: "$3.99",
                    periodLabel: "Monthly",
                    offeringID: "ui-audit",
                    period: .monthly,
                    price: 3.99,
                    billingDescription: "$3.99 per month. Auto-renews unless cancelled."
                ),
                PurchaseProduct(
                    id: "lifetime",
                    title: "Sky Grid Pro Lifetime",
                    priceLabel: "$59.99",
                    periodLabel: "Lifetime",
                    offeringID: "ui-audit",
                    period: .lifetime,
                    price: 59.99,
                    billingDescription: "One payment. No renewal."
                )
            ]
        )
    }

    func purchase(product: PurchaseProduct) async throws -> EntitlementStatus { .notSubscribed }
    func restorePurchases() async throws -> EntitlementStatus { .notSubscribed }
}
#endif

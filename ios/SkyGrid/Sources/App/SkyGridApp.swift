import SwiftUI
import UIKit

@main
struct SkyGridApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var startup = AppStartupController()

    var body: some Scene {
        WindowGroup {
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
    }
}

#if DEBUG
/// A local-only route for simulator screenshots and UI regression tests. It never
/// talks to Firebase, RevenueCat, or a real person’s photo archive, and ships out
/// of Release builds entirely.
private enum UIAuditScenario: String {
    case onboarding
    case today
    case grid
    case buddies
    case paywall
    case paywallPlan = "paywall-plan"
    case settings

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

    init(scenario: UIAuditScenario) {
        self.scenario = scenario
        _selectedTab = State(initialValue: UIAuditTab(scenario: scenario))
        _auditEntitlements = State(initialValue: EntitlementStore(purchases: UIAuditPurchases()))
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
        } else if scenario == .settings {
            NavigationStack {
                SettingsView(
                    uid: UIAuditData.currentUID,
                    accountDeletionService: UIAuditAccountDeletionService(),
                    friendRepository: UIAuditData.friendRepository,
                    userRepository: UIAuditData.userRepository,
                    purchases: UIAuditPurchases(),
                    entitlements: auditEntitlements,
                    onAccountDeleted: {}
                )
            }
        } else {
            NavigationStack {
                TabView(selection: $selectedTab) {
                    TodayView(
                        viewModel: UIAuditData.todayViewModel(),
                        imageFetching: UIAuditImageFetcher(),
                        onOpenCamera: {},
                        subscriptionPlan: .free,
                        onOpenPaywall: {}
                    )
                    .tag(UIAuditTab.today)
                    .tabItem { Label("Today", systemImage: "sun.horizon") }

                    UIAuditGridScreen()
                        .tag(UIAuditTab.grid)
                        .tabItem { Label("Sky Grid", systemImage: "square.grid.3x3.fill") }

                    BuddiesView(
                        uid: UIAuditData.currentUID,
                        friendRepository: UIAuditData.friendRepository,
                        userRepository: UIAuditData.userRepository,
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
        case .onboarding, .today, .paywall, .paywallPlan, .settings: self = .today
        case .grid: self = .grid
        case .buddies: self = .buddies
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

@MainActor
private enum UIAuditData {
    static let currentUID = "ui-audit-user"
    static let fixedClock = FixedClock(
        now: Date(timeIntervalSince1970: 1_785_380_400),
        timeZone: TimeZone(identifier: "UTC")!
    )

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

    init(posts: [SkyPost]) {
        self.posts = posts
    }

    func observePost(uid: String, localDate: LocalDate) -> AsyncStream<SkyPost?> {
        stream(posts.first { $0.ownerUid == uid && $0.localDate == localDate })
    }

    func observePosts(uid: String, from: LocalDate, through: LocalDate) -> AsyncStream<[SkyPost]> {
        stream(posts.filter { $0.ownerUid == uid && $0.localDate >= from && $0.localDate <= through })
    }

    func createPost(_ draft: PostDraft) async throws {}
    func deletePost(uid: String, localDate: LocalDate) async throws {}

    private func stream<T: Sendable>(_ value: T) -> AsyncStream<T> {
        AsyncStream { continuation in
            continuation.yield(value)
            continuation.finish()
        }
    }
}

@MainActor
private final class UIAuditUserRepository: UserRepository {
    private let profiles: [String: UserProfile] = [
        UIAuditData.currentUID: UserProfile(
            uid: UIAuditData.currentUID,
            handle: Handle(raw: "morning_auditor"),
            displayName: "You",
            timezone: "UTC",
            wakeGoalMinutes: 360,
            streakCurrent: 4,
            streakLongest: 8,
            lastPostLocalDate: nil,
            isPro: false
        ),
        "mira": UserProfile(uid: "mira", handle: Handle(raw: "mira_sky"), displayName: "Mira", timezone: "UTC", wakeGoalMinutes: 360, streakCurrent: 3, streakLongest: 5, lastPostLocalDate: nil, isPro: false),
        "ren": UserProfile(uid: "ren", handle: Handle(raw: "ren_wakes"), displayName: "Ren", timezone: "UTC", wakeGoalMinutes: 360, streakCurrent: 7, streakLongest: 12, lastPostLocalDate: nil, isPro: false)
    ]

    func observeProfile(uid: String) -> AsyncStream<UserProfile?> {
        AsyncStream { continuation in
            continuation.yield(profiles[uid])
            continuation.finish()
        }
    }

    func createOrUpdateProfile(_ profile: UserProfile) async throws {}
    func claimHandle(_ handle: Handle, for uid: String) async throws {}
    func findUid(forHandle handle: Handle) async throws -> String? { nil }
}

@MainActor
private final class UIAuditFriendRepository: FriendRepository {
    func observeFriendships(uid: String) -> AsyncStream<[Friendship]> {
        let now = UIAuditData.fixedClock.now
        return AsyncStream { continuation in
            continuation.yield([
                Friendship(pairId: PairID.make(uid, "mira"), members: [uid, "mira"], status: .accepted, requestedBy: uid, createdAt: now, blockedBy: []),
                Friendship(pairId: PairID.make(uid, "ren"), members: [uid, "ren"], status: .accepted, requestedBy: "ren", createdAt: now, blockedBy: [])
            ])
            continuation.finish()
        }
    }

    func observeBlockedFriendships(uid: String) -> AsyncStream<[Friendship]> {
        let now = UIAuditData.fixedClock.now
        return AsyncStream { continuation in
            continuation.yield([
                Friendship(pairId: PairID.make(uid, "kai"), members: [uid, "kai"], status: .accepted, requestedBy: uid, createdAt: now, blockedBy: [uid])
            ])
            continuation.finish()
        }
    }

    func sendRequest(from: String, to: String) async throws {}
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
    func deleteAccount(uid: String) async throws {}
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

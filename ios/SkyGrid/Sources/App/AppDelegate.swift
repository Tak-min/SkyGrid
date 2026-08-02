import FirebaseAppCheck
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

/// The `UNUserNotificationCenter` delegate MUST be assigned here, in
/// `didFinishLaunchingWithOptions`, not later from a SwiftUI `.task` — assigning it
/// late silently drops a cold-start launch from tapping the morning notification,
/// which is this app's single most important interaction path (VISION.md §3, pain
/// #2). See dev-notes for how this was verified.
final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
    let appRouter = AppRouter()
    private var notificationRouter: NotificationRouter?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let router = NotificationRouter(appRouter: appRouter)
        notificationRouter = router
        UNUserNotificationCenter.current().delegate = router

        let launchArguments = ProcessInfo.processInfo.arguments
        let hasFirebaseConfig = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        // UI audit runs use deterministic in-memory view data. They must never
        // create an anonymous Firebase account or contact RevenueCat.
        let isUIAudit = launchArguments.contains("-SkyGridUIAudit")
        let forceUnconfigured = launchArguments.contains("-SkyGridForceFirebaseUnconfigured") || isUIAudit
        if hasFirebaseConfig && !forceUnconfigured {
            #if DEBUG
            // `AppCheckDebugProviderFactory` reads `FIRAAppCheckDebugToken` from the
            // process environment. The Xcode scheme sets that for Xcode-driven runs,
            // but `xcrun devicectl device process launch` (used for physical-device
            // installs) starts the process without it, so a real device silently gets
            // an unregistered random token and every Firestore/Storage request is
            // rejected once App Check enforcement is ON. Force the same
            // already-registered token here so it's independent of launch mechanism.
            if let debugToken = Bundle.main.object(forInfoDictionaryKey: "SGDebugAppCheckToken") as? String,
               !debugToken.isEmpty {
                setenv("FIRAAppCheckDebugToken", debugToken, 1)
            }
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            #else
            AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
            #endif
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
            application.registerForRemoteNotifications()
        }

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        NotificationCenter.default.post(
            name: .skyGridFCMTokenDidChange,
            object: nil,
            userInfo: ["token": fcmToken]
        )
    }
}

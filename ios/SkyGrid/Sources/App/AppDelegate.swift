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

        let hasFirebaseConfig = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        let forceUnconfigured = ProcessInfo.processInfo.arguments.contains("-SkyGridForceFirebaseUnconfigured")
        if hasFirebaseConfig && !forceUnconfigured {
            #if DEBUG
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            #else
            AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
            #endif
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
            application.registerForRemoteNotifications()
        }

        // RevenueCat configuration is independent from Firebase. When no public
        // SDK key is present, the paywall stays unavailable rather than simulating
        // a purchase.
        RevenueCatConfig.configureIfNeeded()

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

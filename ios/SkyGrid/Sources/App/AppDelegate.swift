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
        // Must register during launch, before a background-processing launch has
        // a chance to hand its finite execution window to SwiftUI.
        BackgroundUploadScheduler.register()
        let router = NotificationRouter(appRouter: appRouter)
        notificationRouter = router
        UNUserNotificationCenter.current().delegate = router

        let launchArguments = ProcessInfo.processInfo.arguments
        let hasFirebaseConfig = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        // UI audit runs use deterministic in-memory view data. They must never
        // create an anonymous Firebase account or contact RevenueCat.
        let isUIAudit = launchArguments.contains("-SkyGridUIAudit")
        // Unit-test hosts normally do not exercise Firebase; configuring it there
        // creates a real anonymous account and an untrusted simulator App Check
        // request. The few explicit physical-device integration tests opt in.
        let isRunningTests = NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let allowsFirebaseInTests = launchArguments.contains("-SkyGridAllowFirebaseInTests")
        let forceUnconfigured = launchArguments.contains("-SkyGridForceFirebaseUnconfigured")
            || isUIAudit
            || (isRunningTests && !allowsFirebaseInTests)
        if hasFirebaseConfig && !forceUnconfigured {
            #if DEBUG && targetEnvironment(simulator)
            // `AppCheckDebugProviderFactory` reads `AppCheckDebugToken` from the
            // process environment. The value is for locally registered simulator
            // test tokens only; physical devices use App Attest below.
            if let debugToken = Bundle.main.object(forInfoDictionaryKey: "SGDebugAppCheckToken") as? String,
               !debugToken.isEmpty {
                // Firebase's current Apple SDK reads `AppCheckDebugToken` (not
                // the obsolete `FIRAAppCheckDebugToken`). Using the old name made
                // an enforced production Firestore silently fall back to an
                // unregistered simulator token, so first-account bootstrap failed
                // until someone retried on a different environment.
                setenv("AppCheckDebugToken", debugToken, 1)
            }
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            #else
            // App Attest must also be the path exercised by a physical Debug
            // build. Using the debug provider for every DEBUG build hid an
            // invalid-token failure until Firestore/Storage enforcement was on.
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

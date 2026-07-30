import SwiftUI

@main
struct SkyGridApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var startup = AppStartupController()

    var body: some Scene {
        WindowGroup {
            AppStartupView(startup: startup, appRouter: appDelegate.appRouter)
        }
    }
}

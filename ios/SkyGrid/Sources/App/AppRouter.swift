import Foundation
import Observation

enum AppRoute: Equatable {
    case camera
}

/// Holds a pending navigation request from outside normal UI flow — currently just
/// "a notification was tapped, go straight to the camera" (VISION.md §3, pain #2).
@MainActor
@Observable
final class AppRouter {
    var pendingRoute: AppRoute?

    /// Live Activities cannot directly present the camera. Their only reliable
    /// hand-off is a user tap, which opens this URL and leaves the existing
    /// duplicate-capture guard in `RootView` in charge of the final decision.
    func handle(url: URL) {
        guard url.scheme?.lowercased() == "skygrid",
              url.host?.lowercased() == "capture"
        else { return }
        pendingRoute = .camera
    }
}

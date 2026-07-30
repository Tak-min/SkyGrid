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
}

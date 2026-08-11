import Foundation
import Observation

enum AppRoute: Equatable {
    case camera
}

/// Holds a pending navigation request from outside normal UI flow — currently
/// "a notification was tapped, go straight to the camera" (VISION.md §3, pain #2)
/// and "a Universal Link for an invite was opened."
@MainActor
@Observable
final class AppRouter {
    var pendingRoute: AppRoute?

    /// Set by `handle(url:)`/`handle(userActivity:)` when the URL is an invite link,
    /// and mirrored to `LocalDefaults.pendingInviteCode` so it survives a cold launch
    /// that lands on the auth or onboarding screen before `RootView` exists. Read this
    /// property (not the persisted one) once `RootView` is up — `consumePendingInvite()`
    /// clears both together.
    var pendingInviteCode: InviteCode? {
        didSet {
            guard pendingInviteCode != oldValue else { return }
            LocalDefaults.pendingInviteCode = pendingInviteCode?.value
        }
    }

    init() {
        if let stored = LocalDefaults.pendingInviteCode {
            pendingInviteCode = InviteCode(raw: stored)
        }
    }

    /// An invite link is checked *before* the custom scheme so an `https://skygrid.my`
    /// Universal Link can never be shadowed by it, and so widening the custom scheme
    /// later can never shadow an invite either.
    func handle(url: URL) {
        if let code = InviteLinkParser.code(from: url) {
            pendingInviteCode = code
            return
        }
        guard url.scheme?.lowercased() == "skygrid",
              url.host?.lowercased() == "capture"
        else { return }
        pendingRoute = .camera
    }

    /// `.onOpenURL` is not confirmed to reliably deliver Universal Links on a cold
    /// launch in a `@UIApplicationDelegateAdaptor` app; this is the documented UIKit
    /// path for the same event. Both call into `handle(url:)`, whose `didSet` guard
    /// makes receiving the same link from both harmless.
    func handle(userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL
        else { return }
        handle(url: url)
    }

    /// Call once the pending code has been handed to the claim UI (or the person
    /// dismissed it) — not on every read, or a re-render would silently drop a link
    /// nobody has acted on yet.
    func consumePendingInvite() {
        pendingInviteCode = nil
    }
}

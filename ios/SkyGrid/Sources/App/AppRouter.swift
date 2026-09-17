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

    /// Set when a buddy-post push notification is tapped. Deliberately a separate
    /// slot from `pendingRoute` rather than a new `AppRoute` case: `pendingRoute` is
    /// single-valued, and a buddy-reveal tap arriving after the morning alarm has
    /// already armed `.camera` would silently overwrite the app's single most
    /// important route (VISION.md §3, pain #2) instead of coexisting with it.
    var pendingBuddyRevealRoute = false

    /// Buddy request, approval, and invite-claim pushes open the relationship hub,
    /// not the Today reveal feed. Kept independently pending so a cold launch does
    /// not lose it while authentication/onboarding is resolving.
    var pendingBuddiesRoute = false

    /// Set when the user taps a local "weekly recap ready" notification. The
    /// Today screen consumes this after its seven-day rhythm has loaded so a cold
    /// launch cannot lose the deep link while Firebase is starting.
    var pendingWeeklyRecapRoute = false

    /// Bumped by `NotificationRouter` on *any* buddy-post push arrival — tapped or
    /// merely delivered while foregrounded — so `TodayView` can re-resolve the buddy
    /// strip via `TodayViewModel.refreshBuddiesNow()`. A counter rather than a `Bool`
    /// so two arrivals close together (e.g. two buddies posting minutes apart) are
    /// both observable as distinct `onChange` events, not coalesced into one.
    var buddyRevealRefreshTicks = 0

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
            InviteAnalytics.record(
                url.host?.lowercased() == InviteLinkParser.recoveryHost ? .fallbackRecovered : .linkOpened
            )
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

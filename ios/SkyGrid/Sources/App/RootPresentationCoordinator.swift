import Observation
import OSLog
import SwiftUI

enum RootPresentation: Identifiable {
    case camera
    case reward(RewardMoment)
    case milestone(MilestoneMoment)
    case paywall
    case invite(InviteCode)

    var id: String {
        switch self {
        case .camera: "camera"
        case .reward(let moment): "reward-\(moment.id)"
        case .milestone(let moment): "milestone-\(moment.id)"
        case .paywall: "paywall"
        case .invite: "invite"
        }
    }

    var isFullScreen: Bool {
        switch self {
        case .camera, .reward, .milestone: true
        case .paywall, .invite: false
        }
    }
}

/// One presentation lease spans both the visible and UIKit dismissal phases.
/// Setting a binding to nil starts dismissal; only onDismiss releases the lease.
@MainActor
@Observable
final class RootPresentationCoordinator {
    private(set) var active: RootPresentation?
    private(set) var isDismissing = false
    var childIsPresented = false

    var isAvailable: Bool { active == nil && !childIsPresented }

    /// A refusal is a dropped moment. Every caller today either checks the return
    /// value or has already checked `isAvailable` in the same synchronous stretch, so
    /// nothing is lost — but `RootView`'s binding-shaped setters (`showCamera`,
    /// `rewardMoment`, …) cannot return a value, so a future edit that moves or
    /// loosens one of those guards would drop a reward or a paywall in silence. This
    /// makes that visible in the log rather than invisible.
    @discardableResult
    func present(_ presentation: RootPresentation) -> Bool {
        guard isAvailable else {
            Self.log.warning(
                "refused \(presentation.id, privacy: .public); active=\(self.active?.id ?? "none", privacy: .public) dismissing=\(self.isDismissing) child=\(self.childIsPresented)"
            )
            return false
        }
        active = presentation
        return true
    }

    private static let log = Logger(subsystem: "my.skygrid.app", category: "presentation")

    func dismiss() {
        guard active != nil else { return }
        isDismissing = true
    }

    @discardableResult
    func didDismiss() -> RootPresentation? {
        let dismissed = active
        active = nil
        isDismissing = false
        return dismissed
    }

    /// Releases the lease without a UIKit dismissal callback.
    ///
    /// The lease is deliberately fail-closed: `dismiss()` only ever *starts*
    /// dismissal, and nothing but `didDismiss()` frees the slot. That is the right
    /// trade for racing signals, but it means any presentation that disappears
    /// without SwiftUI running its `onDismiss` would block every later reward,
    /// paywall and invite for the rest of the process.
    ///
    /// No such path is known today — account deletion tears `RootView` down with
    /// its `@State`, so the lease dies with it. This exists so leaving `.today`
    /// (where every cover and sheet below is owned) is correct by construction
    /// rather than by that argument continuing to hold.
    func releaseUnpresented() {
        active = nil
        isDismissing = false
        childIsPresented = false
    }

    func binding(fullScreen: Bool) -> Binding<RootPresentation?> {
        Binding(
            get: {
                guard !self.isDismissing, self.active?.isFullScreen == fullScreen else { return nil }
                return self.active
            },
            set: { value in
                if value == nil, self.active?.isFullScreen == fullScreen { self.dismiss() }
            }
        )
    }
}

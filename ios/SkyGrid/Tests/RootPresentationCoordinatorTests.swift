import Testing
@testable import SkyGrid

@Suite("Root presentation arbitration")
@MainActor
struct RootPresentationCoordinatorTests {
    @Test func delayedSignalsCannotOvertakeCameraDismissal() {
        let coordinator = RootPresentationCoordinator()
        #expect(coordinator.present(.camera))
        coordinator.dismiss()
        #expect(coordinator.binding(fullScreen: true).wrappedValue == nil)
        #expect(!coordinator.isAvailable)
        #expect(!coordinator.present(.paywall))
        #expect(!coordinator.present(.invite(InviteCode(raw: "123456789A")!)))
        #expect(coordinator.didDismiss()?.id == "camera")
        #expect(coordinator.present(.paywall))
    }

    @Test func inviteAndMilestoneCannotClaimSameRunloop() {
        let coordinator = RootPresentationCoordinator()
        #expect(coordinator.present(.invite(InviteCode(raw: "123456789A")!)))
        #expect(!coordinator.present(.camera))
        #expect(!coordinator.present(.paywall))
        #expect(coordinator.binding(fullScreen: true).wrappedValue == nil)
        // Interactive sheet dismissal takes the exact same lease path.
        coordinator.binding(fullScreen: false).wrappedValue = nil
        #expect(!coordinator.isAvailable)
        coordinator.didDismiss()
        #expect(coordinator.isAvailable)
    }

    @Test func childShareKeepsLeaseUntilUIKitDismissCallback() {
        let coordinator = RootPresentationCoordinator()
        coordinator.childIsPresented = true
        #expect(!coordinator.present(.paywall))
        coordinator.childIsPresented = false
        #expect(coordinator.present(.camera))
        // An unrelated binding cannot dismiss a full-screen presentation.
        coordinator.binding(fullScreen: false).wrappedValue = nil
        #expect(!coordinator.isDismissing)
    }

    /// Pins the fail-closed contract in both directions: a started dismissal keeps
    /// the slot until a callback arrives, and `releaseUnpresented()` is the only
    /// other way out. Without the second half, a presentation that vanished
    /// without `onDismiss` would block every later reward, paywall and invite.
    @Test func leaseSurvivesNoDismissCallbackOnlyUntilExplicitRelease() {
        let coordinator = RootPresentationCoordinator()
        let moment = RewardMoment(
            localDate: LocalDate(year: 2026, month: 9, day: 6),
            skyColor: SkyColor(uncheckedHex: "#8FB6D8"),
            thumbnailData: nil
        )
        #expect(coordinator.present(.reward(moment)))
        coordinator.dismiss()
        #expect(!coordinator.isAvailable)
        coordinator.releaseUnpresented()
        #expect(coordinator.isAvailable)
        #expect(coordinator.present(.paywall))
    }

    @Test func releaseAlsoClearsAStuckChildShareSheet() {
        let coordinator = RootPresentationCoordinator()
        coordinator.childIsPresented = true
        #expect(!coordinator.isAvailable)
        coordinator.releaseUnpresented()
        #expect(coordinator.isAvailable)
    }
}

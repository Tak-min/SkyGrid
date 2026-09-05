import Foundation

/// Everything the reward overlay needs about the capture that earned it, frozen at
/// the instant `PostPublisher.publish` succeeds — mirrors `PostCaptureArming`'s
/// "freeze what's known, decide later" shape, but the reward needs no re-asking:
/// publish success is already the truth gate DESIGN.md requires ("Moku may react
/// only to observed state... cannot celebrate before publish success"), so unlike
/// the milestone/paywall arbitration this never waits on a second, asynchronous
/// signal (the streak listener) to know whether to play.
struct RewardMoment: Identifiable, Equatable {
    let id = UUID()
    let localDate: LocalDate
    let skyColor: SkyColor
}

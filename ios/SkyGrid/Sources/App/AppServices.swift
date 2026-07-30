import Foundation

/// All service dependencies a screen might need, bundled for injection via
/// `ServiceEnvironment`. `ServiceFactory` is the only composition root.
@MainActor
struct AppServices {
    let currentUid: String
    let clock: Clock
    let postRepository: any PostRepository
    let userRepository: any UserRepository
    let friendRepository: any FriendRepository
    let contentSafetyRepository: any ContentSafetyRepository
    let accountDeletionService: any AccountDeleting
    let imageFetching: any ImageFetching
    let uploadQueue: UploadQueue
    let postPublisher: any PostPublishing
    let purchases: any PurchasesServicing
    let entitlements: EntitlementStore
    /// Retained so a refreshed FCM token is registered for the active Firebase UID.
    let deviceRegistrar: FirebaseDeviceRegistrar
    /// Retained for the app lifetime so foreground and connectivity events resume
    /// the durable upload outbox rather than only the capture that created it.
    let uploadTriggers: UploadTriggers
    let cameraSourceFactory: () -> CameraSessionController
}

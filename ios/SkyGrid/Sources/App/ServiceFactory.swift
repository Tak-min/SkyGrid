import FirebaseCore
import FirebaseFirestore
import Foundation

/// The composition root for the production backend. There is deliberately no
/// local/demo fallback: if Firebase is unavailable, startup presents a retryable
/// connection state rather than inventing posts, buddies, or purchases.
@MainActor
enum ServiceFactory {
    static func makeAppServices() async throws -> AppServices {
        guard FirebaseApp.app() != nil else {
            throw AppStartupError.firebaseConfigurationMissing
        }

        let uid = try await FirebaseAuthSession.ensureCurrentUser()
        let firestore = Firestore.firestore()
        let postRepository = FirebasePostRepository(firestore: firestore)
        let imageStore = FirebaseImageStore()
        let uploadQueue = UploadQueue(modelContainer: LocalStoreContainer.make(), uploader: makeImageUploader())
        let uploadTriggers = UploadTriggers(queue: uploadQueue)
        let purchases = makePurchasesService()
        let entitlements = EntitlementStore(purchases: purchases)
        let deviceRegistrar = FirebaseDeviceRegistrar(firestore: firestore)
        uploadTriggers.startObserving()
        Task { await uploadQueue.kick() }
        deviceRegistrar.start(for: uid)

        return AppServices(
            currentUid: uid,
            clock: SystemClock(),
            postRepository: postRepository,
            userRepository: FirebaseUserRepository(firestore: firestore),
            friendRepository: FirebaseFriendRepository(firestore: firestore),
            contentSafetyRepository: FirebaseContentSafetyRepository(firestore: firestore),
            accountDeletionService: FirebaseAccountDeletionService(),
            imageFetching: imageStore,
            uploadQueue: uploadQueue,
            postPublisher: PostPublisher(postRepository: postRepository, uploadQueue: uploadQueue),
            purchases: purchases,
            entitlements: entitlements,
            deviceRegistrar: deviceRegistrar,
            uploadTriggers: uploadTriggers,
            cameraSourceFactory: makeCameraSource
        )
    }

    private static func makeImageUploader() -> any ImageUploading {
        FirebaseImageStore()
    }

    private static func makeCameraSource() -> CameraSessionController {
        CameraSessionController()
    }

    private static func makePurchasesService() -> any PurchasesServicing {
        RevenueCatConfig.isConfigured ? RevenueCatService() : UnconfiguredPurchasesService()
    }
}

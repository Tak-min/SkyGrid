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
        let userRepository = FirebaseUserRepository(firestore: firestore)
        // Bootstrap the user document before RevenueCat uses this UID. Its
        // webhook deliberately refuses to recreate deleted/missing accounts;
        // ordering this first prevents a fast purchase from being discarded.
        try await userRepository.ensureInitialProfile(uid: uid)
        try await RevenueCatConfig.configureOrIdentify(appUserID: uid)
        let postRepository = FirebasePostRepository(firestore: firestore)
        let imageStore = FirebaseImageStore()
        let imagePipeline = DisplayImagePipeline(remote: imageStore)
        let uploadQueue = UploadQueue(
            modelContainer: LocalStoreContainer.make(),
            uploader: imageStore,
            postRepository: postRepository
        )
        let uploadTriggers = UploadTriggers(queue: uploadQueue)
        let purchases = makePurchasesService()
        let entitlements = EntitlementStore(purchases: purchases)
        let deviceRegistrar = FirebaseDeviceRegistrar(firestore: firestore)
        uploadTriggers.startObserving()
        Task { await uploadQueue.kick() }
        deviceRegistrar.start(for: uid)
        Task { await MorningAlarmScheduler.resyncIfNeeded() }

        return AppServices(
            currentUid: uid,
            clock: SystemClock(),
            postRepository: postRepository,
            userRepository: userRepository,
            friendRepository: FirebaseFriendRepository(firestore: firestore),
            inviteRepository: FirebaseInviteRepository(),
            contentSafetyRepository: FirebaseContentSafetyRepository(firestore: firestore),
            accountDeletionService: FirebaseAccountDeletionService(uploadQueue: uploadQueue, imagePipeline: imagePipeline),
            imageFetching: imagePipeline,
            uploadQueue: uploadQueue,
            postPublisher: PostPublisher(uploadQueue: uploadQueue),
            orphanedPostRecovery: OrphanedPostRecovery(postRepository: postRepository, uploadQueue: uploadQueue, imageStore: imageStore),
            purchases: purchases,
            entitlements: entitlements,
            deviceRegistrar: deviceRegistrar,
            uploadTriggers: uploadTriggers,
            cameraSourceFactory: makeCameraSource
        )
    }

    private static func makeCameraSource() -> CameraSessionController {
        CameraSessionController()
    }

    private static func makePurchasesService() -> any PurchasesServicing {
        RevenueCatConfig.isConfigured ? RevenueCatService() : UnconfiguredPurchasesService()
    }
}

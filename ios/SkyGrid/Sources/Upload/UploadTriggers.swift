import Foundation
import Network
import UIKit

/// Wires up the moments `UploadQueue.kick()` should fire beyond the initial
/// `enqueue()` call: foreground return and network reachability regained. Firebase
/// Storage uploads don't ride a background `URLSession`, so if the app is closed
/// right after capture, these are what let the upload resume once the app is usable
/// again (blueprint §5.3). `BGProcessingTask` scheduling (the third trigger) is a
/// documented Phase 2 follow-up — see dev-notes — since it needs on-device testing
/// to verify the entitlement/registration wiring.
@MainActor
final class UploadTriggers {
    private let queue: UploadQueue
    private var foregroundObserver: NSObjectProtocol?
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "com.takmin.skygrid.pathmonitor")

    init(queue: UploadQueue) {
        self.queue = queue
    }

    func startObserving() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.queue.kick() }
        }

        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                await self?.queue.kick()
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    func stopObserving() {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        pathMonitor.cancel()
    }
}

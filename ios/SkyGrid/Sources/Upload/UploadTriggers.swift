import BackgroundTasks
import Foundation
import Network
import UIKit

/// Wires up the moments `UploadQueue.kick()` should fire beyond the initial
/// `enqueue()` call: foreground return, network reachability regained, and an iOS
/// background-processing window. Firebase Storage itself is not a background
/// URLSession, so `BGProcessingTask` provides best-effort continuation under iOS's
/// scheduling policy; foreground and relaunch remain durable fallback paths.
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
        BackgroundUploadScheduler.bind(queue: queue)
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.queue.kick()
                BackgroundUploadScheduler.schedule()
            }
        }

        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                guard let self else { return }
                await self.queue.kick()
                BackgroundUploadScheduler.schedule()
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

/// The `BGTaskScheduler` registration is deliberately process-global because iOS
/// invokes it before the SwiftUI dependency graph has been rebuilt. `bind(queue:)`
/// reconnects that early handler to the restored durable outbox once startup has
/// authenticated the account.
@MainActor
enum BackgroundUploadScheduler {
    static let identifier = "com.takmin.skygrid.upload"
    private static var queue: UploadQueue?

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await handle(task)
            }
        }
    }

    static func bind(queue: UploadQueue) {
        self.queue = queue
        schedule()
    }

    static func schedule(earliestBeginDate: Date? = nil) {
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = earliestBeginDate
        // iOS accepts one pending request per identifier. A duplicate submission
        // simply means the already-scheduled request remains the next opportunity.
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGProcessingTask) async {
        guard let queue else {
            task.setTaskCompleted(success: false)
            schedule()
            return
        }

        let work = Task { await queue.processScheduledWork() }
        task.expirationHandler = { work.cancel() }
        await work.value
        task.setTaskCompleted(success: !work.isCancelled)
        schedule()
    }
}

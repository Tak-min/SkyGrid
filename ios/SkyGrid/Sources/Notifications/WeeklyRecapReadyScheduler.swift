import Foundation
import UIKit
import UserNotifications

/// Fires a local notification once the rolling 7-day weekly recap becomes ready
/// (all 7 days posted). Fires immediately when the condition is first met,
/// then cancels itself to avoid repeat firings for the same recap window.
@MainActor
enum WeeklyRecapReadyScheduler {
    nonisolated static let identifierPrefix = "com.takmin.skygrid.weekly-recap-ready."

    /// Identifier is keyed by the recap's end date (the current day when all 7 are posted).
    static func identifier(for localDate: LocalDate) -> String {
        identifierPrefix + localDate.docID
    }

    /// Returns true if the recap is newly ready. A recap is ready when all 7 days
    /// have been posted. We consider it "newly" ready if there's no pending notification
    /// for this recap window yet.
    static func isRecapNewlyReady(_ rhythm: WeekRhythm) -> Bool {
        WeeklyRecapPolicy.isReady(rhythm)
    }

    /// Fires an immediate notification (or near-immediate, within a second) to notify
    /// the user that their weekly recap is ready to view. Safe to call even if already
    /// fired — uses an idempotent check to avoid stacking duplicates.
    static func notifyRecapReady(
        endDate: LocalDate,
        posts: [SkyPost],
        imageFetching: any ImageFetching
    ) async {
        if let last = LocalDefaults.lastWeeklyRecapNotificationLocalDate.flatMap(LocalDate.init(docID:)),
           last.daysUntil(endDate) < 7 {
            return
        }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let authorized = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        guard authorized else { return }

        // Check if we've already fired for this recap window to avoid duplicates.
        let pendingRequests = await center.pendingNotificationRequests()
        let id = identifier(for: endDate)
        if pendingRequests.contains(where: { $0.identifier == id }) {
            return
        }

        let delivered = await center.deliveredNotifications()
        if delivered.contains(where: { $0.request.identifier == id }) {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = L10n.string("notification.weeklyRecapReady.title")
        content.body = L10n.string("notification.weeklyRecapReady.body")
        content.sound = .default
        content.userInfo = ["type": "weekly_recap_ready", "localDate": endDate.docID]
        if let attachment = await recapAttachment(
            endDate: endDate,
            posts: posts,
            imageFetching: imageFetching
        ) {
            content.attachments = [attachment]
        }

        // Fire immediately (next runloop).
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        do {
            try await center.add(request)
            LocalDefaults.lastWeeklyRecapNotificationLocalDate = endDate.docID
        } catch {
            // A failed add must not consume the seven-day slot; the next rhythm
            // snapshot or foreground pass can retry it.
        }
    }

    /// Builds the existing seven-photo recap card for the expanded notification.
    /// The notification variant intentionally omits the handle and invite link:
    /// notification previews can appear on a locked screen.
    private static func recapAttachment(
        endDate: LocalDate,
        posts: [SkyPost],
        imageFetching: any ImageFetching
    ) async -> UNNotificationAttachment? {
        let sortedPosts = Array(posts.sorted { $0.localDate < $1.localDate }.suffix(7))
        guard sortedPosts.count == 7 else { return nil }

        var photos: [LocalDate: UIImage] = [:]
        for post in sortedPosts {
            let path = post.thumbPath
            guard let data = try? await imageFetching.fetchImage(path: path),
                  let image = UIImage(data: data)
            else { continue }
            photos[post.localDate] = image
        }
        guard let image = ShareCardRenderer.renderWeekly(
            posts: sortedPosts,
            photos: photos,
            handle: nil,
            inviteLinkURL: nil
        ), let data = image.jpegData(compressionQuality: 0.82) else { return nil }

        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WeeklyRecapNotifications", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let fileURL = folder.appendingPathComponent("recap-\(endDate.docID).jpg")
            try data.write(to: fileURL, options: .atomic)
            return try UNNotificationAttachment(identifier: "weekly-recap-image", url: fileURL)
        } catch {
            // The text notification remains useful if an image failed to download,
            // render, or attach. Do not consume a second notification slot.
            return nil
        }
    }

    /// Cancels the notification for a specific recap window.
    static func cancel(for localDate: LocalDate) {
        let center = UNUserNotificationCenter.current()
        let id = identifier(for: localDate)
        Task {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            center.removeDeliveredNotifications(withIdentifiers: [id])
        }
    }

    /// Cancels all weekly recap notifications.
    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pendingIDs = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)

        let deliveredIDs = await center.deliveredNotifications()
            .map(\.request.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
    }
}

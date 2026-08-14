import UserNotifications

/// Requests system notification permission at the moment a buddy pairing succeeds —
/// the first point the buddy-post push notification (`onBuddyPostCreated`) actually
/// has anything to notify about. Until now, permission was only ever requested from
/// `MorningAlarmScheduler`, gated behind someone opting into the morning wake flow —
/// so anyone who paired with a buddy without also enabling that flow had no way to
/// ever receive this push (owner's decision, 2026-08-14: ask here too).
///
/// Mirrors the fire-and-forget request already used in `MorningAlarmScheduler.swift`:
/// a denial here only means this specific push never arrives, nothing else in the app
/// depends on it, and `requestAuthorization` itself no-ops safely if permission was
/// already granted or denied.
enum BuddyPairingNotificationPermission {
    static func requestIfNeeded() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
}

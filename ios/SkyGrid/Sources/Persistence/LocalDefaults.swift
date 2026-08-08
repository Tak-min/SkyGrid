import Foundation

/// `Optional<Wrapped>` values passed through a generic `T` parameter double-box when
/// bridged to `Any?`, so `UserDefaults.set(_:forKey:)` receives a non-property-list
/// object and CoreFoundation raises an uncaught exception. Detecting the nil case
/// through this protocol lets the wrapper route it to `removeObject` instead.
private protocol AnyOptional {
    var isNilValue: Bool { get }
}

extension Optional: AnyOptional {
    var isNilValue: Bool { self == nil }
}

@propertyWrapper
struct UserDefaultBacked<T> {
    let key: String
    let defaultValue: T

    var wrappedValue: T {
        get { UserDefaults.standard.object(forKey: key) as? T ?? defaultValue }
        set {
            if let optional = newValue as? AnyOptional, optional.isNilValue {
                UserDefaults.standard.removeObject(forKey: key)
            } else {
                UserDefaults.standard.set(newValue, forKey: key)
            }
        }
    }
}

/// The single place any code reads/writes `UserDefaults` — no other file should call
/// `UserDefaults.standard` with a raw string key.
enum LocalDefaults {
    @UserDefaultBacked(key: "lastKnownTimeZoneIdentifier", defaultValue: nil)
    static var lastKnownTimeZoneIdentifier: String?

    @UserDefaultBacked(key: "handle", defaultValue: nil)
    static var handle: String?

    /// Default 6:00 AM (360 minutes after midnight).
    @UserDefaultBacked(key: "wakeGoalMinutes", defaultValue: 360)
    static var wakeGoalMinutes: Int

    @UserDefaultBacked(key: "onboardingDone", defaultValue: false)
    static var onboardingDone: Bool

    @UserDefaultBacked(key: "personalizationProfile", defaultValue: nil)
    private static var personalizationProfileData: Data?

    /// Preference answers remain on-device. They are intentionally not added to
    /// the account model or any future analytics payload.
    static var personalizationProfile: PersonalizationProfile {
        get {
            guard let personalizationProfileData,
                  let profile = try? JSONDecoder().decode(PersonalizationProfile.self, from: personalizationProfileData)
            else { return PersonalizationProfile() }
            return profile
        }
        set {
            personalizationProfileData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Automatic prompts are based only on a successfully persisted capture's
    /// local calendar date. They never record photos, preference answers, wake
    /// times, or any other personal data.
    @UserDefaultBacked(key: "automaticPaywallAccountID", defaultValue: nil)
    static var automaticPaywallAccountID: String?

    @UserDefaultBacked(key: "completedCaptureCount", defaultValue: 0)
    static var completedCaptureCount: Int

    @UserDefaultBacked(key: "lastCompletedCaptureLocalDate", defaultValue: nil)
    static var lastCompletedCaptureLocalDate: String?

    @UserDefaultBacked(key: "lastAutomaticPaywallPromptCaptureCount", defaultValue: nil)
    static var lastAutomaticPaywallPromptCaptureCount: Int?

    @UserDefaultBacked(key: "lastAutomaticPaywallPromptLocalDate", defaultValue: nil)
    static var lastAutomaticPaywallPromptLocalDate: String?

    @UserDefaultBacked(key: "consecutiveAutomaticPaywallDismissals", defaultValue: 0)
    static var consecutiveAutomaticPaywallDismissals: Int

    @UserDefaultBacked(key: "automaticPaywallSnoozedUntil", defaultValue: nil)
    static var automaticPaywallSnoozedUntil: Date?

    /// Set the first time `AppReviewPromptPolicy` decides a completed capture is
    /// a good moment to call SwiftUI's `requestReview` environment action. Not
    /// reset by `resetAutomaticPaywallState()` — an unrelated paywall-state reset
    /// must not re-arm a review ask that already fired this install.
    @UserDefaultBacked(key: "hasRequestedAppReview", defaultValue: false)
    static var hasRequestedAppReview: Bool

    /// The highest streak milestone already celebrated on this install — a monotonic
    /// high-water mark, so each threshold fires at most once. Deliberately **not**
    /// cleared by `resetAutomaticPaywallState()`, for the same reason as
    /// `hasRequestedAppReview`: an unrelated paywall-state reset must never re-arm a
    /// moment that already fired.
    @UserDefaultBacked(key: "lastCelebratedStreakMilestone", defaultValue: 0)
    static var lastCelebratedStreakMilestone: Int

    /// Scopes the high-water mark to an account, so signing in as someone else does
    /// not inherit their celebrated milestones. Mirrors `automaticPaywallAccountID`
    /// but is kept separate so nothing milestone-related can perturb paywall state.
    @UserDefaultBacked(key: "milestoneAccountID", defaultValue: nil)
    static var milestoneAccountID: String?

    static func resetMilestoneState() {
        lastCelebratedStreakMilestone = 0
        milestoneAccountID = nil
    }

    static func resetAutomaticPaywallState() {
        automaticPaywallAccountID = nil
        completedCaptureCount = 0
        lastCompletedCaptureLocalDate = nil
        lastAutomaticPaywallPromptCaptureCount = nil
        lastAutomaticPaywallPromptLocalDate = nil
        consecutiveAutomaticPaywallDismissals = 0
        automaticPaywallSnoozedUntil = nil
    }

    /// The user has explicitly turned on their morning wake flow. This is a user
    /// preference only; the scheduler still checks AlarmKit / notification state
    /// before it claims an alarm exists.
    @UserDefaultBacked(key: "morningAlarmEnabled", defaultValue: false)
    static var morningAlarmEnabled: Bool

    /// `automatic` selects AlarmKit whenever the OS supports it. `reminder` is
    /// written only after someone explicitly chooses the iOS 17–25-style fallback
    /// on a newer device after denying AlarmKit access.
    @UserDefaultBacked(key: "morningAlarmBackend", defaultValue: "automatic")
    static var morningAlarmBackend: String

    /// Set by the AlarmKit stop intent. The app consumes it once the scene becomes
    /// active, which makes the system alarm's dismissal lead straight to capture.
    @UserDefaultBacked(key: "openCameraAfterMorningAlarm", defaultValue: false)
    static var openCameraAfterMorningAlarm: Bool

    /// The `LocalDate.docID` of the most recent completed capture, used only to
    /// decide whether the morning ritual Live Activity/follow-up notification are
    /// still relevant. Deliberately separate from `lastCompletedCaptureLocalDate`
    /// (paywall-scoped, wiped by `resetAutomaticPaywallState()`) — an unrelated
    /// paywall-state reset must never re-arm a nudge for a day already captured.
    @UserDefaultBacked(key: "lastCapturedLocalDateID", defaultValue: nil)
    static var lastCapturedLocalDateID: String?

    static func resetAccountScopedValues() {
        lastKnownTimeZoneIdentifier = nil
        handle = nil
        wakeGoalMinutes = 360
        onboardingDone = false
        personalizationProfileData = nil
        resetAutomaticPaywallState()
        resetMilestoneState()
        morningAlarmEnabled = false
        morningAlarmBackend = "automatic"
        openCameraAfterMorningAlarm = false
        lastCapturedLocalDateID = nil
    }
}

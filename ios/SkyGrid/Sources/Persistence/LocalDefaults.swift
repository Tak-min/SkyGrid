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
    }

    /// Scopes the one-shot first-unlock paywall to an account, kept separate from
    /// `automaticPaywallAccountID` for the same reason `milestoneAccountID` is
    /// separate from it — nothing unlock-paywall-related may perturb the capture
    /// count `AppReviewPromptPolicy` reads.
    @UserDefaultBacked(key: "unlockPaywallAccountID", defaultValue: nil)
    static var unlockPaywallAccountID: String?

    /// Set only by the path that actually presented the first-unlock paywall
    /// (`RootView.recordAutomaticPaywallPresentationIfNeeded`), never at the decision
    /// site — a milestone that outranks the paywall this time must leave this `nil`
    /// so the very next re-ask can still offer it. `nil` forever after that means
    /// "never shown"; non-`nil` means "shown exactly once, permanently."
    @UserDefaultBacked(key: "unlockPaywallPresentedAt", defaultValue: nil)
    static var unlockPaywallPresentedAt: Date?

    static func resetUnlockPaywallState() {
        unlockPaywallAccountID = nil
        unlockPaywallPresentedAt = nil
    }

    /// Scopes the cadenced solo-morning paywall to an account, kept separate from
    /// `unlockPaywallAccountID`/`automaticPaywallAccountID`/`milestoneAccountID` for
    /// the same reason each of those is separate — nothing solo-paywall-related may
    /// perturb any other automatic prompt's bookkeeping.
    @UserDefaultBacked(key: "soloPaywallAccountID", defaultValue: nil)
    static var soloPaywallAccountID: String?

    /// `completedCaptureCount` at the moment the solo paywall was last presented.
    /// `nil` means "never presented" — distinct from `0`, which would falsely satisfy
    /// `SoloMorningPaywallPolicy`'s "captured enough since last prompt" check on the
    /// very first eligible capture.
    @UserDefaultBacked(key: "lastSoloPaywallPromptCaptureCount", defaultValue: nil)
    static var lastSoloPaywallPromptCaptureCount: Int?

    /// `LocalDate.docID` of the day the solo paywall was last presented. Stored as a
    /// string (Firestore/`UserDefaults`-safe), parsed back to `LocalDate` at the read
    /// site — mirrors `lastCompletedCaptureLocalDate`.
    @UserDefaultBacked(key: "lastSoloPaywallPromptLocalDate", defaultValue: nil)
    static var lastSoloPaywallPromptLocalDate: String?

    /// Consecutive solo-paywall presentations dismissed without purchasing. Reset to
    /// `0` the moment a purchase succeeds; drives `SoloMorningPaywallPolicy.snoozeUntil`.
    @UserDefaultBacked(key: "consecutiveSoloPaywallDismissals", defaultValue: 0)
    static var consecutiveSoloPaywallDismissals: Int

    /// `nil` means "no snooze in effect." Set by `SoloMorningPaywallPolicy.snoozeUntil`
    /// after repeated dismissals; a `Date` (not a `Bool`) so it self-expires on its own
    /// schedule rather than needing an explicit clear on every calendar-day rollover.
    @UserDefaultBacked(key: "soloPaywallSnoozedUntil", defaultValue: nil)
    static var soloPaywallSnoozedUntil: Date?

    static func resetSoloPaywallState() {
        soloPaywallAccountID = nil
        lastSoloPaywallPromptCaptureCount = nil
        lastSoloPaywallPromptLocalDate = nil
        consecutiveSoloPaywallDismissals = 0
        soloPaywallSnoozedUntil = nil
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

    /// The canonical `InviteCode.value` of a link tapped before `RootView` could act
    /// on it — cold launch (auth screen, onboarding) can outlive the in-memory
    /// `AppRouter.pendingInviteCode`, so this is what survives to the next
    /// `resolvePendingPresentations()` pass. Deliberately not cleared by
    /// `resetAccountScopedValues()`: which account eventually consumes a tapped link
    /// is unrelated to which account was previously signed in.
    @UserDefaultBacked(key: "pendingInviteCode", defaultValue: nil)
    static var pendingInviteCode: String?

    /// `LocalDate.docID` of the day `skygrid_mutual_reveal_unlocked` last fired.
    /// Persisted (not an in-memory `TodayViewModel` property) because the metric's
    /// contract is "fires at most once per calendar day" — an in-memory flag would
    /// refire on every relaunch after the buddy strip is already unlocked that day,
    /// inflating the funnel this instrumentation exists to measure.
    @UserDefaultBacked(key: "mutualRevealUnlockedLocalDate", defaultValue: nil)
    static var mutualRevealUnlockedLocalDate: String?

    /// Scopes the above to an account, mirroring `milestoneAccountID` — signing in
    /// as someone else must not inherit their already-fired date.
    @UserDefaultBacked(key: "mutualRevealUnlockedAccountID", defaultValue: nil)
    static var mutualRevealUnlockedAccountID: String?

    static func resetMutualRevealAnalyticsState() {
        mutualRevealUnlockedLocalDate = nil
        mutualRevealUnlockedAccountID = nil
    }

    static func resetAccountScopedValues() {
        lastKnownTimeZoneIdentifier = nil
        handle = nil
        wakeGoalMinutes = 360
        onboardingDone = false
        personalizationProfileData = nil
        resetAutomaticPaywallState()
        resetUnlockPaywallState()
        resetSoloPaywallState()
        resetMilestoneState()
        resetMutualRevealAnalyticsState()
        morningAlarmEnabled = false
        morningAlarmBackend = "automatic"
        openCameraAfterMorningAlarm = false
        lastCapturedLocalDateID = nil
    }
}

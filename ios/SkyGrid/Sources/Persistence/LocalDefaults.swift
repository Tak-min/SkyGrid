import Foundation

@propertyWrapper
struct UserDefaultBacked<T> {
    let key: String
    let defaultValue: T

    var wrappedValue: T {
        get { UserDefaults.standard.object(forKey: key) as? T ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
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

    /// A voluntary exit offer is shown at most once per installation. This avoids
    /// repeatedly interrupting someone who has explicitly chosen the free tier.
    @UserDefaultBacked(key: "didPresentExitOffer", defaultValue: false)
    static var didPresentExitOffer: Bool

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

    static func resetAccountScopedValues() {
        lastKnownTimeZoneIdentifier = nil
        handle = nil
        wakeGoalMinutes = 360
        onboardingDone = false
        personalizationProfileData = nil
        didPresentExitOffer = false
        morningAlarmEnabled = false
        morningAlarmBackend = "automatic"
        openCameraAfterMorningAlarm = false
    }
}

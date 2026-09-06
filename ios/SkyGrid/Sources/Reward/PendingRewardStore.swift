import Foundation

/// A reward that has been earned but not yet shown.
///
/// The bytes are deliberately not stored — only the Storage path they can be read
/// back from. A morning's thumbnail is tens of kilobytes and `UserDefaults` is the
/// wrong home for that; `RewardOverlayView` already degrades to the recorded sky
/// colour when no thumbnail resolves, so a missing file costs the photo, not the
/// celebration.
struct PendingRewardRecord: Equatable, Sendable {
    let localDate: LocalDate
    let skyColor: SkyColor
    let thumbPath: String
}

/// Carries an earned reward across process death.
///
/// `armDailyReward` records the reward the instant `PostPublisher.publish` succeeds,
/// and only the presentation itself marks the day played. Holding the moment purely
/// in `@State` therefore lost it outright if the app was terminated in between — a
/// capture the user had already made, celebrated by nothing.
struct PendingRewardStore {
    let defaults: UserDefaults
    private let dateKey = "pendingReward.localDate"
    private let colorKey = "pendingReward.skyColorHex"
    private let thumbKey = "pendingReward.thumbPath"

    static let standard = PendingRewardStore(defaults: .standard)

    func save(_ record: PendingRewardRecord) {
        defaults.set(record.localDate.docID, forKey: dateKey)
        defaults.set(record.skyColor.hex, forKey: colorKey)
        defaults.set(record.thumbPath, forKey: thumbKey)
    }

    /// `today` is required, not optional: a record from an earlier morning must not
    /// resurface. The daily reward answers for the capture that just happened, and a
    /// celebration arriving a day late reads as a bug rather than a reward.
    func load(today: LocalDate) -> PendingRewardRecord? {
        guard let docID = defaults.string(forKey: dateKey),
              let localDate = LocalDate(docID: docID),
              localDate == today,
              let hex = defaults.string(forKey: colorKey),
              let skyColor = SkyColor(hex: hex),
              let thumbPath = defaults.string(forKey: thumbKey)
        else { return nil }
        return PendingRewardRecord(localDate: localDate, skyColor: skyColor, thumbPath: thumbPath)
    }

    func clear() {
        defaults.removeObject(forKey: dateKey)
        defaults.removeObject(forKey: colorKey)
        defaults.removeObject(forKey: thumbKey)
    }
}

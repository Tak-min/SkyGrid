import Foundation

struct MokuAmbientMessage: Equatable {
    enum Topic: String, CaseIterable, Equatable {
        case morningRecord
        case buddySection
        case mosaicEntry
        case rhythmSection
        case heading
        case emptyMorningRecord
        case captureButton
        case shareButton
    }

    enum Category: Equatable {
        case photo
        case buddyActivity
        case streak
        case ambient
        case beforeCapture
        case mosaic
    }

    struct Context: Equatable {
        let isPostStatusKnown: Bool
        let hasPostedToday: Bool
        let hasBuddies: Bool
        let hasBuddyPostToday: Bool
        let streak: Int
    }

    let topic: Topic
    let category: Category
    let text: String
    let mokuState: MokuState
}

enum MokuAmbientMessagePolicy {
    /// Intentionally modest: Moku should feel discovered, not like a recurring prompt.
    static let appearanceProbability = 0.30

    static func shouldAnimate(reduceMotion: Bool) -> Bool {
        !reduceMotion && MokuMotionPolicy.animationsEnabled
    }

    /// A visit may spend the once-per-day slot only after the Today data source
    /// has answered. This keeps a cold launch from consuming the slot while the
    /// first Firestore snapshot is still in flight.
    static func canConsumeDailySlot(for context: MokuAmbientMessage.Context) -> Bool {
        context.isPostStatusKnown
    }

    static func eligibleTopics(for context: MokuAmbientMessage.Context) -> [MokuAmbientMessage.Topic] {
        var topics: [MokuAmbientMessage.Topic] = [.mosaicEntry, .heading]

        if context.hasPostedToday || (context.isPostStatusKnown && !context.hasPostedToday) {
            topics.append(.morningRecord)
        }
        if context.hasBuddies {
            topics.append(.buddySection)
        }
        if context.streak >= 1 {
            topics.append(.rhythmSection)
        }
        if context.isPostStatusKnown && !context.hasPostedToday {
            topics.append(contentsOf: [.emptyMorningRecord, .captureButton])
        }
        if context.hasPostedToday {
            topics.append(.shareButton)
        }

        return MokuAmbientMessage.Topic.allCases.filter(topics.contains)
    }

    static func selectionForVisit(
        context: MokuAmbientMessage.Context,
        today: LocalDate,
        lastPresentedLocalDateID: String?,
        randomUnit: Double,
        topicIndex: Int,
        messageIndex: Int
    ) -> MokuAmbientMessage? {
        guard lastPresentedLocalDateID != today.docID else { return nil }
        guard randomUnit >= 0, randomUnit < appearanceProbability else { return nil }

        let topics = eligibleTopics(for: context)
        guard !topics.isEmpty else { return nil }
        let topic = topics[wrapped: topicIndex]
        let messages = messagePool(for: topic, context: context)
        guard !messages.isEmpty else { return nil }
        let message = messages[wrapped: messageIndex]
        return MokuAmbientMessage(
            topic: topic,
            category: message.category,
            text: message.text,
            mokuState: message.state
        )
    }

    static func randomSelectionForVisit(
        context: MokuAmbientMessage.Context,
        today: LocalDate,
        lastPresentedLocalDateID: String?
    ) -> MokuAmbientMessage? {
        selectionForVisit(
            context: context,
            today: today,
            lastPresentedLocalDateID: lastPresentedLocalDateID,
            randomUnit: Double.random(in: 0..<1),
            topicIndex: Int.random(in: 0..<Int.max),
            messageIndex: Int.random(in: 0..<Int.max)
        )
    }

#if DEBUG
    static func forcedSelection(
        topic: MokuAmbientMessage.Topic,
        messageIndex: Int,
        context: MokuAmbientMessage.Context,
        today: LocalDate
    ) -> MokuAmbientMessage? {
        let topics = eligibleTopics(for: context)
        guard let topicIndex = topics.firstIndex(of: topic) else { return nil }
        return selectionForVisit(
            context: context,
            today: today,
            lastPresentedLocalDateID: nil,
            randomUnit: 0,
            topicIndex: topicIndex,
            messageIndex: messageIndex
        )
    }
#endif

    static func allPossibleMessages(streak: Int = 3, language: AppLanguage? = nil) -> [String] {
        let contexts = [
            MokuAmbientMessage.Context(
                isPostStatusKnown: true,
                hasPostedToday: false,
                hasBuddies: false,
                hasBuddyPostToday: false,
                streak: streak
            ),
            MokuAmbientMessage.Context(
                isPostStatusKnown: true,
                hasPostedToday: true,
                hasBuddies: true,
                hasBuddyPostToday: false,
                streak: streak
            ),
            MokuAmbientMessage.Context(
                isPostStatusKnown: true,
                hasPostedToday: true,
                hasBuddies: true,
                hasBuddyPostToday: true,
                streak: streak
            ),
        ]

        return contexts.flatMap { context in
            MokuAmbientMessage.Topic.allCases.flatMap { topic in
                messagePool(for: topic, context: context, language: language).map(\.text)
            }
        }
    }

    private struct MessageTemplate {
        let category: MokuAmbientMessage.Category
        let text: String
        let state: MokuState
    }

    private static func messagePool(
        for topic: MokuAmbientMessage.Topic,
        context: MokuAmbientMessage.Context,
        language: AppLanguage? = nil
    ) -> [MessageTemplate] {
        switch topic {
        case .morningRecord where context.hasPostedToday:
            return photoMessages(language: language)
        case .morningRecord, .emptyMorningRecord, .captureButton:
            return beforeCaptureMessages(language: language)
        case .buddySection where context.hasBuddyPostToday:
            return buddyActivityMessages(language: language)
        case .buddySection:
            return ambientMessages(language: language)
        case .mosaicEntry:
            return mosaicMessages(language: language)
        case .rhythmSection:
            let text = context.streak == 1
                ? L10n.string("moku.rhythm.oneMorningKept", language: language)
                : String(format: L10n.string("moku.rhythm.streakCount", language: language), context.streak)
            return [MessageTemplate(category: .streak, text: text, state: .delight)]
        case .heading:
            return ambientMessages(language: language)
        case .shareButton:
            return [
                MessageTemplate(
                    category: .photo,
                    text: L10n.string("moku.share.mightBrightenDay", language: language),
                    state: .delight
                ),
                MessageTemplate(
                    category: .photo,
                    text: L10n.string("moku.share.worthPassingAlong", language: language),
                    state: .settled
                ),
            ]
        }
    }

    // Routed through `L10n.string(_:)` (explicit key lookup), not plain string
    // literals: every message here is stored as `MokuAmbientMessage.text: String` and
    // displayed via `Text(text)` (`MokuAmbientBubble.swift`) — a stored-property
    // consumer, not a `Text("literal")` call site — so SwiftUI's automatic String
    // Catalog key matching never applies (see `dev-notes/localization-en-ja-stage2_*.md`).
    //
    // These are computed `static func`, not `static let`: a `let` would resolve
    // `L10n.string(...)` exactly once (Swift lazily initializes a `static let` on
    // first access and caches it for the process lifetime), freezing every message
    // in whichever language was active the first time it was read — silently
    // breaking immediate in-app language switching for any category already seen
    // before a language change. Recomputing on every call keeps them live.

    private static func photoMessages(language: AppLanguage?) -> [MessageTemplate] {
        [
            MessageTemplate(category: .photo, text: L10n.string("moku.photo.coloredEarnedMorning", language: language), state: .delight),
            MessageTemplate(category: .photo, text: L10n.string("moku.photo.skyLeftGoodOne", language: language), state: .settled),
            MessageTemplate(category: .photo, text: L10n.string("moku.photo.lightHasStory", language: language), state: .delight),
        ]
    }

    private static func buddyActivityMessages(language: AppLanguage?) -> [MessageTemplate] {
        [
            MessageTemplate(category: .buddyActivity, text: L10n.string("moku.buddy.circleAlreadyLookedUp", language: language), state: .delight),
            MessageTemplate(category: .buddyActivity, text: L10n.string("moku.buddy.twoMorningsFoundEachOther", language: language), state: .delight),
            MessageTemplate(category: .buddyActivity, text: L10n.string("moku.buddy.familiarSkyWaiting", language: language), state: .settled),
        ]
    }

    private static func ambientMessages(language: AppLanguage?) -> [MessageTemplate] {
        [
            MessageTemplate(category: .ambient, text: L10n.string("moku.ambient.skiesChangeMind", language: language), state: .ready),
            MessageTemplate(category: .ambient, text: L10n.string("moku.ambient.morningLightNeverRepeats", language: language), state: .ready),
            MessageTemplate(category: .ambient, text: L10n.string("moku.ambient.dayLooksDifferent", language: language), state: .settled),
        ]
    }

    private static func beforeCaptureMessages(language: AppLanguage?) -> [MessageTemplate] {
        [
            MessageTemplate(category: .beforeCapture, text: L10n.string("moku.beforeCapture.wonderWhatsUpThere", language: language), state: .ready),
            MessageTemplate(category: .beforeCapture, text: L10n.string("moku.beforeCapture.noRushStillBecoming", language: language), state: .settled),
            MessageTemplate(category: .beforeCapture, text: L10n.string("moku.beforeCapture.maybeNewColor", language: language), state: .ready),
        ]
    }

    private static func mosaicMessages(language: AppLanguage?) -> [MessageTemplate] {
        [
            MessageTemplate(category: .mosaic, text: L10n.string("moku.mosaic.gridQuietlyFilling", language: language), state: .ready),
            MessageTemplate(category: .mosaic, text: L10n.string("moku.mosaic.everySquareRemembers", language: language), state: .settled),
            MessageTemplate(category: .mosaic, text: L10n.string("moku.mosaic.peekYearChangingColor", language: language), state: .ready),
        ]
    }
}

private extension Array {
    subscript(wrapped index: Int) -> Element {
        self[index % count]
    }
}

import Foundation

struct MokuAmbientMessage: Equatable {
    enum Anchor: CaseIterable, Equatable {
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

    let anchor: Anchor
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

    static func eligibleAnchors(for context: MokuAmbientMessage.Context) -> [MokuAmbientMessage.Anchor] {
        var anchors: [MokuAmbientMessage.Anchor] = [.mosaicEntry, .heading]

        if context.hasPostedToday || (context.isPostStatusKnown && !context.hasPostedToday) {
            anchors.append(.morningRecord)
        }
        if context.hasBuddies {
            anchors.append(.buddySection)
        }
        if context.streak >= 1 {
            anchors.append(.rhythmSection)
        }
        if context.isPostStatusKnown && !context.hasPostedToday {
            anchors.append(contentsOf: [.emptyMorningRecord, .captureButton])
        }
        if context.hasPostedToday {
            anchors.append(.shareButton)
        }

        return MokuAmbientMessage.Anchor.allCases.filter(anchors.contains)
    }

    static func selectionForVisit(
        context: MokuAmbientMessage.Context,
        today: LocalDate,
        lastPresentedLocalDateID: String?,
        randomUnit: Double,
        anchorIndex: Int,
        messageIndex: Int
    ) -> MokuAmbientMessage? {
        guard lastPresentedLocalDateID != today.docID else { return nil }
        guard randomUnit >= 0, randomUnit < appearanceProbability else { return nil }

        let anchors = eligibleAnchors(for: context)
        guard !anchors.isEmpty else { return nil }
        let anchor = anchors[wrapped: anchorIndex]
        let messages = messagePool(for: anchor, context: context)
        guard !messages.isEmpty else { return nil }
        let message = messages[wrapped: messageIndex]
        return MokuAmbientMessage(
            anchor: anchor,
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
            anchorIndex: Int.random(in: 0..<Int.max),
            messageIndex: Int.random(in: 0..<Int.max)
        )
    }

    static func allPossibleMessages(streak: Int = 3) -> [String] {
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
            MokuAmbientMessage.Anchor.allCases.flatMap { anchor in
                messagePool(for: anchor, context: context).map(\.text)
            }
        }
    }

    private struct MessageTemplate {
        let category: MokuAmbientMessage.Category
        let text: String
        let state: MokuState
    }

    private static func messagePool(
        for anchor: MokuAmbientMessage.Anchor,
        context: MokuAmbientMessage.Context
    ) -> [MessageTemplate] {
        switch anchor {
        case .morningRecord where context.hasPostedToday:
            return photoMessages
        case .morningRecord, .emptyMorningRecord, .captureButton:
            return beforeCaptureMessages
        case .buddySection where context.hasBuddyPostToday:
            return buddyActivityMessages
        case .buddySection:
            return ambientMessages
        case .mosaicEntry:
            return mosaicMessages
        case .rhythmSection:
            let text = context.streak == 1
                ? L10n.string("moku.rhythm.oneMorningKept")
                : String(format: L10n.string("moku.rhythm.streakCount"), context.streak)
            return [MessageTemplate(category: .streak, text: text, state: .delight)]
        case .heading:
            return ambientMessages
        case .shareButton:
            return [
                MessageTemplate(
                    category: .photo,
                    text: L10n.string("moku.share.mightBrightenDay"),
                    state: .delight
                ),
                MessageTemplate(
                    category: .photo,
                    text: L10n.string("moku.share.worthPassingAlong"),
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
    // These are computed `static var`, not `static let`: a `let` would resolve
    // `L10n.string(...)` exactly once (Swift lazily initializes a `static let` on
    // first access and caches it for the process lifetime), freezing every message
    // in whichever language was active the first time it was read — silently
    // breaking immediate in-app language switching for any category already seen
    // before a language change. Recomputing on every access keeps them live.

    private static var photoMessages: [MessageTemplate] {
        [
            MessageTemplate(category: .photo, text: L10n.string("moku.photo.coloredEarnedMorning"), state: .delight),
            MessageTemplate(category: .photo, text: L10n.string("moku.photo.skyLeftGoodOne"), state: .settled),
            MessageTemplate(category: .photo, text: L10n.string("moku.photo.lightHasStory"), state: .delight),
        ]
    }

    private static var buddyActivityMessages: [MessageTemplate] {
        [
            MessageTemplate(category: .buddyActivity, text: L10n.string("moku.buddy.circleAlreadyLookedUp"), state: .delight),
            MessageTemplate(category: .buddyActivity, text: L10n.string("moku.buddy.twoMorningsFoundEachOther"), state: .delight),
            MessageTemplate(category: .buddyActivity, text: L10n.string("moku.buddy.familiarSkyWaiting"), state: .settled),
        ]
    }

    private static var ambientMessages: [MessageTemplate] {
        [
            MessageTemplate(category: .ambient, text: L10n.string("moku.ambient.skiesChangeMind"), state: .ready),
            MessageTemplate(category: .ambient, text: L10n.string("moku.ambient.morningLightNeverRepeats"), state: .ready),
            MessageTemplate(category: .ambient, text: L10n.string("moku.ambient.dayLooksDifferent"), state: .settled),
        ]
    }

    private static var beforeCaptureMessages: [MessageTemplate] {
        [
            MessageTemplate(category: .beforeCapture, text: L10n.string("moku.beforeCapture.wonderWhatsUpThere"), state: .ready),
            MessageTemplate(category: .beforeCapture, text: L10n.string("moku.beforeCapture.noRushStillBecoming"), state: .settled),
            MessageTemplate(category: .beforeCapture, text: L10n.string("moku.beforeCapture.maybeNewColor"), state: .ready),
        ]
    }

    private static var mosaicMessages: [MessageTemplate] {
        [
            MessageTemplate(category: .mosaic, text: L10n.string("moku.mosaic.gridQuietlyFilling"), state: .ready),
            MessageTemplate(category: .mosaic, text: L10n.string("moku.mosaic.everySquareRemembers"), state: .settled),
            MessageTemplate(category: .mosaic, text: L10n.string("moku.mosaic.peekYearChangingColor"), state: .ready),
        ]
    }
}

private extension Array {
    subscript(wrapped index: Int) -> Element {
        self[index % count]
    }
}

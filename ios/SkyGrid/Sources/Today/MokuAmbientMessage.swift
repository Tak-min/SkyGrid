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
                ? "One morning kept. That's how a rhythm begins."
                : "\(context.streak) mornings in a row. Quietly impressive."
            return [MessageTemplate(category: .streak, text: text, state: .delight)]
        case .heading:
            return ambientMessages
        case .shareButton:
            return [
                MessageTemplate(
                    category: .photo,
                    text: "This morning might brighten someone's day.",
                    state: .delight
                ),
                MessageTemplate(
                    category: .photo,
                    text: "A sky like that is worth passing along.",
                    state: .settled
                ),
            ]
        }
    }

    private static let photoMessages = [
        MessageTemplate(category: .photo, text: "That color looks like it earned its morning.", state: .delight),
        MessageTemplate(category: .photo, text: "The sky left a good one for you today.", state: .settled),
        MessageTemplate(category: .photo, text: "That light has a story in it.", state: .delight),
    ]

    private static let buddyActivityMessages = [
        MessageTemplate(category: .buddyActivity, text: "Someone in your circle already looked up today.", state: .delight),
        MessageTemplate(category: .buddyActivity, text: "Two mornings just found each other.", state: .delight),
        MessageTemplate(category: .buddyActivity, text: "A familiar sky is waiting beside yours.", state: .settled),
    ]

    private static let ambientMessages = [
        MessageTemplate(category: .ambient, text: "Skies change their mind a lot before noon.", state: .ready),
        MessageTemplate(category: .ambient, text: "Morning light never repeats itself.", state: .ready),
        MessageTemplate(category: .ambient, text: "The day looks different when you remember to look up.", state: .settled),
    ]

    private static let beforeCaptureMessages = [
        MessageTemplate(category: .beforeCapture, text: "Wonder what's up there today.", state: .ready),
        MessageTemplate(category: .beforeCapture, text: "No rush. The sky is still becoming itself.", state: .settled),
        MessageTemplate(category: .beforeCapture, text: "Maybe today has a color you haven't met yet.", state: .ready),
    ]

    private static let mosaicMessages = [
        MessageTemplate(category: .mosaic, text: "Your grid is quietly filling in.", state: .ready),
        MessageTemplate(category: .mosaic, text: "Every little square remembers a morning.", state: .settled),
        MessageTemplate(category: .mosaic, text: "Peek at how the year is changing color.", state: .ready),
    ]
}

private extension Array {
    subscript(wrapped index: Int) -> Element {
        self[index % count]
    }
}

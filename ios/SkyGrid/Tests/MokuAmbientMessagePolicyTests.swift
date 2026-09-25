import Testing
@testable import SkyGrid

@Suite("Moku ambient messages")
struct MokuAmbientMessagePolicyTests {
    private let today = LocalDate(year: 2026, month: 9, day: 9)

    @Test("all eight topics become eligible across the reachable contexts that admit them")
    func allTopicsCanBecomeEligible() {
        // `.emptyMorningRecord` / `.captureButton` require "not posted yet" and
        // `.shareButton` requires "posted" — mutually exclusive states, so no
        // single context can ever surface all eight at once. The real claim is
        // that every topic is reachable by *some* real context.
        let postedTopics = MokuAmbientMessagePolicy.eligibleTopics(
            for: context(posted: true, buddies: true, buddyPosted: true, streak: 4)
        )
        let notPostedTopics = MokuAmbientMessagePolicy.eligibleTopics(
            for: context(posted: false, buddies: false, buddyPosted: false, streak: 0)
        )

        let reachable = Set(postedTopics).union(notPostedTopics)
        #expect(reachable == Set(MokuAmbientMessage.Topic.allCases))
    }

    @Test("only currently valid topics participate before capture")
    func preCaptureTopics() {
        let topics = MokuAmbientMessagePolicy.eligibleTopics(
            for: context(posted: false, buddies: false, buddyPosted: false, streak: 0)
        )

        #expect(topics == [.morningRecord, .mosaicEntry, .heading, .emptyMorningRecord, .captureButton])
        #expect(!topics.contains(.buddySection))
        #expect(!topics.contains(.rhythmSection))
        #expect(!topics.contains(.shareButton))
    }

    @Test("unknown post state still has always-valid topics")
    func unknownPostState() {
        let context = MokuAmbientMessage.Context(
            isPostStatusKnown: false,
            hasPostedToday: false,
            hasBuddies: false,
            hasBuddyPostToday: false,
            streak: 0
        )

        #expect(MokuAmbientMessagePolicy.eligibleTopics(for: context) == [.mosaicEntry, .heading])
        #expect(!MokuAmbientMessagePolicy.canConsumeDailySlot(for: context))
    }

    @Test("resolved post state may consume the daily slot")
    func resolvedPostStateCanConsumeDailySlot() {
        #expect(MokuAmbientMessagePolicy.canConsumeDailySlot(
            for: context(posted: false, buddies: false, buddyPosted: false, streak: 0)
        ))
    }

    @Test("the probability gate is thirty percent")
    func probabilityGate() {
        let context = context(posted: true, buddies: false, buddyPosted: false, streak: 0)

        #expect(selection(context: context, randomUnit: 0.299_999) != nil)
        #expect(selection(context: context, randomUnit: 0.30) == nil)
        #expect(MokuAmbientMessagePolicy.appearanceProbability == 0.30)
    }

    @Test("same calendar day cooldown prevents another message")
    func sameDayCooldown() {
        let result = MokuAmbientMessagePolicy.selectionForVisit(
            context: context(posted: true, buddies: true, buddyPosted: true, streak: 2),
            today: today,
            lastPresentedLocalDateID: today.docID,
            randomUnit: 0,
            topicIndex: 0,
            messageIndex: 0
        )

        #expect(result == nil)
        #expect(selection(
            context: context(posted: true, buddies: true, buddyPosted: true, streak: 2),
            lastPresentedLocalDateID: today.adding(days: -1).docID
        ) != nil)
    }

    @Test("buddy activity copy requires a real buddy post today")
    func buddyActivityIsTruthful() {
        let withoutPost = selection(
            context: context(posted: true, buddies: true, buddyPosted: false, streak: 0),
            topic: .buddySection
        )
        let withPost = selection(
            context: context(posted: true, buddies: true, buddyPosted: true, streak: 0),
            topic: .buddySection
        )

        #expect(withoutPost?.category == .ambient)
        #expect(withPost?.category == .buddyActivity)
    }

    @Test("message pool contains no monetization language")
    func noMonetizationLanguage() {
        let forbidden = ["upgrade", "pro", "price", "pricing", "plan", "premium", "subscription", "$", "paywall"]
        let messages = MokuAmbientMessagePolicy.allPossibleMessages()

        #expect(!messages.isEmpty)
        for message in messages {
            let normalized = message.lowercased()
            #expect(forbidden.allSatisfy { !normalized.contains($0) }, "Forbidden monetization copy in: \(message)")
        }
    }

    @Test("message pool contains no location-referencing language, in English or Japanese")
    func noLocationReferencingLanguage() {
        let forbiddenEnglish = ["square", "circle"]
        let forbiddenJapanese = ["マス", "サークル", "下の"]

        let englishMessages = MokuAmbientMessagePolicy.allPossibleMessages(language: .english)
        let japaneseMessages = MokuAmbientMessagePolicy.allPossibleMessages(language: .japanese)

        #expect(!englishMessages.isEmpty)
        #expect(!japaneseMessages.isEmpty)

        for message in englishMessages {
            let normalized = message.lowercased()
            #expect(forbiddenEnglish.allSatisfy { !normalized.contains($0) }, "Location-referencing copy in: \(message)")
        }
        for message in japaneseMessages {
            #expect(forbiddenJapanese.allSatisfy { !message.contains($0) }, "Location-referencing copy in: \(message)")
        }
    }

    @Test("Reduce Motion always disables the bubble animation")
    func reduceMotionIsStatic() {
        #expect(!MokuAmbientMessagePolicy.shouldAnimate(reduceMotion: true))
    }

    private func selection(
        context: MokuAmbientMessage.Context,
        lastPresentedLocalDateID: String? = nil,
        randomUnit: Double = 0,
        topic: MokuAmbientMessage.Topic? = nil
    ) -> MokuAmbientMessage? {
        let eligible = MokuAmbientMessagePolicy.eligibleTopics(for: context)
        let topicIndex = topic.flatMap(eligible.firstIndex) ?? 0
        return MokuAmbientMessagePolicy.selectionForVisit(
            context: context,
            today: today,
            lastPresentedLocalDateID: lastPresentedLocalDateID,
            randomUnit: randomUnit,
            topicIndex: topicIndex,
            messageIndex: 0
        )
    }

    private func context(
        posted: Bool,
        buddies: Bool,
        buddyPosted: Bool,
        streak: Int
    ) -> MokuAmbientMessage.Context {
        MokuAmbientMessage.Context(
            isPostStatusKnown: true,
            hasPostedToday: posted,
            hasBuddies: buddies,
            hasBuddyPostToday: buddyPosted,
            streak: streak
        )
    }
}

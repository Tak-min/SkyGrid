import Foundation
import Testing
@testable import SkyGrid

@Suite("AppReviewPromptPolicy")
struct AppReviewPromptPolicyTests {
    @Test("waits for the trigger capture count before asking")
    func waitsForTriggerCount() {
        #expect(!AppReviewPromptPolicy.shouldRequest(completedCaptureCount: 6, hasRequestedBefore: false))
        #expect(AppReviewPromptPolicy.shouldRequest(completedCaptureCount: 7, hasRequestedBefore: false))
        #expect(AppReviewPromptPolicy.shouldRequest(completedCaptureCount: 30, hasRequestedBefore: false))
    }

    @Test("never asks twice in the same install")
    func neverAsksTwice() {
        #expect(!AppReviewPromptPolicy.shouldRequest(completedCaptureCount: 7, hasRequestedBefore: true))
        #expect(!AppReviewPromptPolicy.shouldRequest(completedCaptureCount: 100, hasRequestedBefore: true))
    }
}

import Testing
@testable import SkyGrid

@Suite("RetryPolicy")
struct RetryPolicyTests {
    @Test("delay grows exponentially with attempt count, before jitter")
    func delayGrowsExponentially() {
        #expect(RetryPolicy.delay(forAttempt: 1, jitter: 1.0) == 2)
        #expect(RetryPolicy.delay(forAttempt: 2, jitter: 1.0) == 4)
        #expect(RetryPolicy.delay(forAttempt: 3, jitter: 1.0) == 8)
    }

    @Test("delay is capped")
    func delayIsCapped() {
        #expect(RetryPolicy.delay(forAttempt: 20, jitter: 1.0) == RetryPolicy.cap)
    }

    @Test("jitter scales the base delay proportionally")
    func jitterScalesDelay() {
        #expect(RetryPolicy.delay(forAttempt: 2, jitter: 0.75) == 3)
        #expect(RetryPolicy.delay(forAttempt: 2, jitter: 1.25) == 5)
    }
}

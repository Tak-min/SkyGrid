const test = require("node:test");
const assert = require("node:assert/strict");

const {
  RATE_LIMITS,
  RATE_LIMIT_WINDOW_MS,
  rateLimitDecision,
} = require("../lib/rateLimit.js");

const NOW = 1_786_000_000_000;
const WINDOW = RATE_LIMIT_WINDOW_MS;
const LIMIT = 20;

test("a caller with no history is allowed and opens a window at the current time", () => {
  const decision = rateLimitDecision(null, NOW, WINDOW, LIMIT);

  assert.equal(decision.allowed, true);
  assert.deepEqual(decision.nextWindow, { windowStartMs: NOW, count: 1 });
});

test("a call inside a live window increments without moving the window's start", () => {
  const current = { windowStartMs: NOW, count: 5 };
  const decision = rateLimitDecision(current, NOW + 60_000, WINDOW, LIMIT);

  assert.equal(decision.allowed, true);
  // Sliding the start on every call would let a steady stream of requests keep the
  // window open forever and never reset the count.
  assert.deepEqual(decision.nextWindow, { windowStartMs: NOW, count: 6 });
});

test("the last call under the limit is allowed and the first at the limit is not", () => {
  const under = rateLimitDecision({ windowStartMs: NOW, count: LIMIT - 1 }, NOW, WINDOW, LIMIT);
  const at = rateLimitDecision({ windowStartMs: NOW, count: LIMIT }, NOW, WINDOW, LIMIT);

  assert.equal(under.allowed, true);
  assert.equal(under.nextWindow.count, LIMIT);
  assert.equal(at.allowed, false);
});

test("a rejected call writes nothing, so a flood stays cheap and cannot extend itself", () => {
  const decision = rateLimitDecision({ windowStartMs: NOW, count: LIMIT + 9 }, NOW, WINDOW, LIMIT);

  assert.equal(decision.allowed, false);
  assert.equal(decision.nextWindow, null);
});

test("an elapsed window resets rather than accumulating across hours", () => {
  const decision = rateLimitDecision(
    { windowStartMs: NOW, count: LIMIT + 100 },
    NOW + WINDOW,
    WINDOW,
    LIMIT
  );

  assert.equal(decision.allowed, true);
  assert.deepEqual(decision.nextWindow, { windowStartMs: NOW + WINDOW, count: 1 });
});

test("the window boundary is exclusive: one millisecond early is still inside it", () => {
  const decision = rateLimitDecision(
    { windowStartMs: NOW, count: LIMIT },
    NOW + WINDOW - 1,
    WINDOW,
    LIMIT
  );

  assert.equal(decision.allowed, false);
});

test("the caller's stored window is never mutated", () => {
  const current = { windowStartMs: NOW, count: 3 };
  rateLimitDecision(current, NOW + 1000, WINDOW, LIMIT);

  assert.deepEqual(current, { windowStartMs: NOW, count: 3 });
});

test("every callable that can create cost or relationship state carries a limit", () => {
  // `previewInvite` is the obvious oracle, but `claimInvite` reveals the same fact.
  // Limiting only preview would be bypassed by calling claim instead.
  for (const action of ["preview", "claim", "create", "buddyRequest", "buddyAccept"]) {
    assert.equal(typeof RATE_LIMITS[action], "number");
    assert.ok(RATE_LIMITS[action] > 0);
  }
});

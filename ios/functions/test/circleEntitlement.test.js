const test = require("node:test");
const assert = require("node:assert/strict");

const {
  CircleEntitlementRequiredError,
  RevenueCatEntitlementUnavailableError,
  fetchLiveCircleLimit,
  hasActivePremiumEntitlement,
  limitsOrRequireLiveEntitlements,
} = require("../lib/circleEntitlement.js");
const { FREE_CIRCLE_LIMIT, PRO_CIRCLE_LIMIT } = require("../lib/invites.js");

const NOW = Date.parse("2026-09-09T12:00:00Z");
const payload = (premium) => ({ subscriber: { entitlements: premium === undefined ? {} : { premium } } });

test("RevenueCat premium parsing distinguishes active, grace, expired, and lifetime access", () => {
  assert.equal(hasActivePremiumEntitlement(payload({ expires_date: null }), NOW), true);
  assert.equal(hasActivePremiumEntitlement(payload({ expires_date: "2026-09-10T00:00:00Z" }), NOW), true);
  assert.equal(hasActivePremiumEntitlement(payload({
    expires_date: "2026-09-08T00:00:00Z",
    grace_period_expires_date: "2026-09-10T00:00:00Z",
  }), NOW), true);
  assert.equal(hasActivePremiumEntitlement(payload({ expires_date: "2026-09-08T00:00:00Z" }), NOW), false);
  assert.equal(hasActivePremiumEntitlement(payload(undefined), NOW), false);
  assert.equal(hasActivePremiumEntitlement({ malformed: true }, NOW), false);
});

test("live lookup uses the premium entitlement and never trusts a product id", async () => {
  let observedAuthorization;
  const fetchImpl = async (_url, init) => {
    observedAuthorization = init.headers.Authorization;
    return new Response(JSON.stringify(payload({ expires_date: null, product_identifier: "anything" })), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  };
  assert.equal(await fetchLiveCircleLimit({ uid: "user/id", apiKey: "secret", nowMs: NOW, fetchImpl }), PRO_CIRCLE_LIMIT);
  assert.equal(observedAuthorization, "Bearer secret");
});

test("live lookup treats a successful inactive response as Free", async () => {
  const fetchImpl = async () => new Response(JSON.stringify(payload({
    expires_date: "2026-09-08T00:00:00Z",
  })), { status: 200 });
  assert.equal(await fetchLiveCircleLimit({ uid: "free", apiKey: "secret", nowMs: NOW, fetchImpl }), FREE_CIRCLE_LIMIT);
});

test("live lookup leaves status unresolved on transport, HTTP, JSON, or secret failures", async () => {
  const cases = [
    () => Promise.reject(new Error("offline")),
    async () => new Response("busy", { status: 429 }),
    async () => new Response("not-json", { status: 200 }),
  ];
  for (const fetchImpl of cases) {
    await assert.rejects(
      fetchLiveCircleLimit({ uid: "user", apiKey: "secret", nowMs: NOW, fetchImpl }),
      RevenueCatEntitlementUnavailableError,
    );
  }
  await assert.rejects(
    fetchLiveCircleLimit({ uid: "user", apiKey: "", nowMs: NOW }),
    RevenueCatEntitlementUnavailableError,
  );
});

test("Free-sized operations need no live lookup; sixth edges do", () => {
  assert.deepEqual(limitsOrRequireLiveEntitlements({
    inviterUid: "a",
    claimerUid: "b",
    inviterAcceptedCount: 4,
    claimerAcceptedCount: 4,
    resolveEntitlementIfNeeded: true,
  }), { inviterLimit: 5, claimerLimit: 5 });

  assert.throws(() => limitsOrRequireLiveEntitlements({
    inviterUid: "a",
    claimerUid: "b",
    inviterAcceptedCount: 5,
    claimerAcceptedCount: 0,
    resolveEntitlementIfNeeded: true,
  }), CircleEntitlementRequiredError);
});

test("UID-keyed limits cannot be reused after a participant changes", () => {
  assert.throws(() => limitsOrRequireLiveEntitlements({
    inviterUid: "new-recipient",
    claimerUid: "caller",
    inviterAcceptedCount: 5,
    claimerAcceptedCount: 0,
    suppliedLimitsByUid: { "old-recipient": 15, caller: 5 },
    resolveEntitlementIfNeeded: true,
  }), CircleEntitlementRequiredError);
});

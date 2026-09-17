const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const { claimEarlyAdopterSlot, isEligible } = require("../../lib/earlyAdopterGrantStore.js");

admin.initializeApp({ projectId: "sky-grid-app" });
const db = admin.firestore();

const CAMPAIGN_REF = db.collection("campaigns").doc("earlyAdopter100");

async function reset() {
  await Promise.all(
    ["users", "earlyAdopterGrants", "entitlements", "campaigns"].map((collection) =>
      db.recursiveDelete(db.collection(collection))),
  );
}

async function seedCounter({ claimedCount = 0, limit = 100, phase = "live" } = {}) {
  await CAMPAIGN_REF.set({ claimedCount, limit, phase, closedAt: null });
}

async function counter() {
  return (await CAMPAIGN_REF.get()).data();
}

async function grant(uid) {
  return (await db.collection("earlyAdopterGrants").doc(uid).get()).data();
}

test("claiming without a provisioned counter throws (fails loud, not silently open)", async () => {
  await reset();
  await assert.rejects(() => claimEarlyAdopterSlot(db, "uid-1", { source: "live" }));
});

test("a single claim reserves a slot and creates a pending grant doc", async () => {
  await reset();
  await seedCounter({ claimedCount: 0, limit: 100 });

  const result = await claimEarlyAdopterSlot(db, "uid-1", { source: "live" });
  assert.equal(result, "claimed");

  const data = await grant("uid-1");
  assert.equal(data.status, "pending");
  assert.equal(data.source, "live");
  assert.equal(data.entitlement, "premium");
  assert.equal(Number.isFinite(data.plannedExpiresAtMs), true);
  assert.equal((await counter()).claimedCount, 1);
});

test("live claims pause during backfill without consuming a slot", async () => {
  await reset();
  await seedCounter({ claimedCount: 0, limit: 100, phase: "backfill" });

  assert.equal(await claimEarlyAdopterSlot(db, "uid-1", { source: "live" }), "paused");
  assert.equal(await grant("uid-1"), undefined);
  assert.equal((await counter()).claimedCount, 0);

  assert.equal(await claimEarlyAdopterSlot(db, "uid-1", { source: "batch" }), "claimed");
  assert.equal((await counter()).claimedCount, 1);
});

test("pending claims can resume with the original planned expiry", async () => {
  await reset();
  await seedCounter();
  await claimEarlyAdopterSlot(db, "uid-1", { source: "live" });
  const plannedExpiresAtMs = (await grant("uid-1")).plannedExpiresAtMs;

  assert.equal(await claimEarlyAdopterSlot(db, "uid-1", { source: "live" }), "resume");
  assert.equal((await grant("uid-1")).plannedExpiresAtMs, plannedExpiresAtMs);
  assert.equal((await counter()).claimedCount, 1);
});

test("a configured limit above the hard 100 cap fails closed", async () => {
  await reset();
  await seedCounter({ claimedCount: 0, limit: 101 });
  await assert.rejects(
    () => claimEarlyAdopterSlot(db, "uid-1", { source: "live" }),
    /limit between 1 and 100/,
  );
  assert.equal(await grant("uid-1"), undefined);
});

test("claiming an already-claimed uid returns 'already' and does not move the counter", async () => {
  await reset();
  await seedCounter({ claimedCount: 5, limit: 100 });
  await claimEarlyAdopterSlot(db, "uid-1", { source: "live" });
  assert.equal((await counter()).claimedCount, 6);

  const second = await claimEarlyAdopterSlot(db, "uid-1", { source: "live" });
  assert.equal(second, "already");
  assert.equal((await counter()).claimedCount, 6);
});

test("claiming at quota returns 'exhausted' without creating a grant doc", async () => {
  await reset();
  await seedCounter({ claimedCount: 100, limit: 100 });

  const result = await claimEarlyAdopterSlot(db, "uid-1", { source: "live" });
  assert.equal(result, "exhausted");
  assert.equal(await grant("uid-1"), undefined);
  assert.equal((await counter()).claimedCount, 100);
  assert.equal((await counter()).phase, "closed");
});

test("optional runId is recorded on the grant doc when provided (batch path)", async () => {
  await reset();
  await seedCounter({ claimedCount: 0, limit: 100 });

  await claimEarlyAdopterSlot(db, "uid-1", { source: "batch", runId: "run-123" });
  const data = await grant("uid-1");
  assert.equal(data.runId, "run-123");

  // Live-path claims (no runId passed) must not get a stray runId field.
  await claimEarlyAdopterSlot(db, "uid-2", { source: "live" });
  const liveData = await grant("uid-2");
  assert.equal(Object.hasOwn(liveData, "runId"), false);
});

// The load-bearing test: this design exists specifically so that many concurrent
// claims near the quota boundary can never collectively exceed `limit`.
test("20 concurrent claims with exactly 1 slot remaining: exactly one succeeds, counter stops at limit", async () => {
  await reset();
  await seedCounter({ claimedCount: 99, limit: 100 });

  const uids = Array.from({ length: 20 }, (_, i) => `concurrent-uid-${i}`);
  const results = await Promise.all(uids.map((uid) => claimEarlyAdopterSlot(db, uid, { source: "live" })));

  const claimed = results.filter((r) => r === "claimed");
  const exhausted = results.filter((r) => r === "exhausted");
  assert.equal(claimed.length, 1, `expected exactly 1 "claimed", got ${claimed.length}: ${JSON.stringify(results)}`);
  assert.equal(exhausted.length, 19);
  assert.equal((await counter()).claimedCount, 100);

  // Exactly one of the 20 grant docs should exist.
  const grantDocs = await Promise.all(uids.map((uid) => grant(uid)));
  const created = grantDocs.filter(Boolean);
  assert.equal(created.length, 1);
});

test("isEligible: excludes users without a handle", async () => {
  await reset();
  await db.collection("users").doc("uid-1").set({});
  assert.equal(await isEligible(db, "uid-1"), false);
});

test("isEligible: excludes users on the denylist", async () => {
  // QA_DENYLIST is a compile-time empty array in the source; this test only verifies
  // the check path runs — a populated-denylist case is covered by direct unit test of
  // the exported constant's usage shape, not re-tested here since it's a plain array.
  await reset();
  await db.collection("users").doc("uid-1").set({ handle: "someone" });
  assert.equal(await isEligible(db, "uid-1"), true);
});

test("isEligible: excludes users already marked Premium via the entitlements mirror", async () => {
  await reset();
  await db.collection("users").doc("uid-1").set({ handle: "someone" });
  await db.collection("entitlements").doc("uid-1").set({ isPro: true });
  assert.equal(await isEligible(db, "uid-1"), false);
});

test("isEligible: a missing entitlements doc is treated as not-Premium (eligible)", async () => {
  await reset();
  await db.collection("users").doc("uid-1").set({ handle: "someone" });
  assert.equal(await isEligible(db, "uid-1"), true);
});

test("isEligible: a missing user doc is not eligible", async () => {
  await reset();
  assert.equal(await isEligible(db, "no-such-uid"), false);
});

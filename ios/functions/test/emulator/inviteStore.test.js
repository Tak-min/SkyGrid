const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const {
  AccountUnavailableError,
  MalformedFriendshipError,
  MissingHandleError,
  claimInvite,
  consumeRateLimit,
  createInviteForUser,
  previewInviteCode,
  revokeInviteDocument,
} = require("../../lib/inviteStore.js");
const { INVITE_TTL_MS } = require("../../lib/invites.js");
const { RATE_LIMITS } = require("../../lib/rateLimit.js");

/**
 * The half of the invite feature that pure tests cannot reach: what Firestore actually
 * does under concurrency, and what shape the friendship document really lands in.
 *
 * Lives in `test/emulator/` on purpose — `npm test`'s glob is `test/*.test.js`, so this
 * file does not make the ordinary test run require a running emulator. Use
 * `npm run test:emulator`.
 */

admin.initializeApp({ projectId: "sky-grid-app" });
const db = admin.firestore();

const NOW = 1_786_000_000_000;

async function reset() {
  for (const collection of ["invites", "friendships", "users", "inviteRateLimits"]) {
    const snapshot = await db.collection(collection).get();
    await Promise.all(snapshot.docs.map((document) => document.ref.delete()));
  }
}

async function makeUser(uid, handle) {
  await db.collection("users").doc(uid).set({ handle, displayName: "Sky Grid member" });
}

test("a claimed invite writes a friendship the security rules would accept", async () => {
  await reset();
  await makeUser("creator", "mira_sky");
  await makeUser("claimer", "theo_dawn");

  const created = await createInviteForUser(db, "creator", NOW);
  const result = await claimInvite(db, { code: created.code, callerUid: "claimer", nowMs: NOW });

  assert.equal(result.outcome, "paired");

  const friendship = (await db.collection("friendships").doc(result.pairId).get()).data();

  // The exact key set `firestore.rules` whitelists on create. A server write that adds
  // or omits one is a document the rules could never have produced, and `activeBuddy()`
  // errors on a missing `blockedBy` — which denies reads for the *other* member.
  assert.deepEqual(
    Object.keys(friendship).sort(),
    ["blockedBy", "createdAt", "members", "recipientHandle", "requestedBy", "requestedByHandle", "status"]
  );
  assert.deepEqual(friendship.members, ["claimer", "creator"]);
  assert.ok(friendship.members[0] < friendship.members[1], "members must be sorted");
  assert.equal(friendship.requestedBy, "creator");
  assert.equal(friendship.requestedByHandle, "mira_sky");
  assert.equal(friendship.recipientHandle, "theo_dawn");
  assert.deepEqual(friendship.blockedBy, []);
  assert.equal(friendship.status, "accepted");
  assert.ok(friendship.createdAt instanceof admin.firestore.Timestamp);

  const invite = (await db.collection("invites").doc(created.code).get()).data();
  assert.equal(invite.status, "claimed");
  assert.equal(invite.claimedByUid, "claimer");
});

test("two people racing for one code produce exactly one pairing", async () => {
  await reset();
  await makeUser("creator", "mira_sky");
  await makeUser("first", "first_one");
  await makeUser("second", "second_one");

  const created = await createInviteForUser(db, "creator", NOW);
  const results = await Promise.all([
    claimInvite(db, { code: created.code, callerUid: "first", nowMs: NOW }),
    claimInvite(db, { code: created.code, callerUid: "second", nowMs: NOW }),
  ]);

  const outcomes = results.map((each) => each.outcome).sort();
  assert.deepEqual(outcomes, ["claimed", "paired"]);

  const friendships = await db.collection("friendships").get();
  assert.equal(friendships.size, 1, "the loser must not also get a pair");
});

test("the same person claiming twice stays paired and writes nothing the second time", async () => {
  await reset();
  await makeUser("creator", "mira_sky");
  await makeUser("claimer", "theo_dawn");

  const created = await createInviteForUser(db, "creator", NOW);
  const first = await claimInvite(db, { code: created.code, callerUid: "claimer", nowMs: NOW });
  const afterFirst = await db.collection("invites").doc(created.code).get();

  const second = await claimInvite(db, { code: created.code, callerUid: "claimer", nowMs: NOW + 5000 });
  const afterSecond = await db.collection("invites").doc(created.code).get();

  // A double tap or a retried network call must not tell someone their own successful
  // pairing was stolen.
  assert.equal(first.outcome, "paired");
  assert.equal(second.outcome, "paired");
  assert.deepEqual(afterFirst.updateTime, afterSecond.updateTime, "the retry must not write");
});

test("a pending request is promoted rather than duplicated", async () => {
  await reset();
  await makeUser("creator", "mira_sky");
  await makeUser("claimer", "theo_dawn");
  await db.collection("friendships").doc("claimer_creator").set({
    members: ["claimer", "creator"],
    status: "pending",
    requestedBy: "claimer",
    createdAt: admin.firestore.Timestamp.fromMillis(NOW - 1000),
    blockedBy: [],
  });

  const created = await createInviteForUser(db, "creator", NOW);
  const result = await claimInvite(db, { code: created.code, callerUid: "claimer", nowMs: NOW });

  assert.equal(result.outcome, "paired");
  assert.equal((await db.collection("friendships").get()).size, 1);
  assert.equal(
    (await db.collection("friendships").doc("claimer_creator").get()).data().status,
    "accepted"
  );
});

test("a blocked pair cannot be resurrected, and the link survives for after an unblock", async () => {
  await reset();
  await makeUser("creator", "mira_sky");
  await makeUser("claimer", "theo_dawn");
  await db.collection("friendships").doc("claimer_creator").set({
    members: ["claimer", "creator"],
    status: "accepted",
    requestedBy: "creator",
    createdAt: admin.firestore.Timestamp.fromMillis(NOW - 1000),
    blockedBy: ["claimer"],
  });

  const created = await createInviteForUser(db, "creator", NOW);
  const result = await claimInvite(db, { code: created.code, callerUid: "claimer", nowMs: NOW });

  assert.equal(result.outcome, "blocked");
  assert.equal(
    (await db.collection("invites").doc(created.code).get()).data().status,
    "open",
    "a block must not burn the code"
  );
});

test("a claim against a deleted creator is a dead link, not a half-written pair", async () => {
  await reset();
  await makeUser("creator", "mira_sky");
  await makeUser("claimer", "theo_dawn");

  const created = await createInviteForUser(db, "creator", NOW);
  await db.collection("users").doc("creator").delete();

  const preview = await previewInviteCode(db, created.code, "claimer", NOW);
  const result = await claimInvite(db, { code: created.code, callerUid: "claimer", nowMs: NOW });

  assert.deepEqual(preview, { state: "unknown" });
  assert.equal(result.outcome, "unknown");
  assert.equal((await db.collection("friendships").get()).size, 0);
});

test("account deletion markers stop create and claim without exposing code existence", async () => {
  await reset();
  await makeUser("creator", "mira_sky");
  await makeUser("claimer", "theo_dawn");
  const created = await createInviteForUser(db, "creator", NOW);

  await db.collection("users").doc("creator").update({
    deletionRequestedAt: admin.firestore.Timestamp.fromMillis(NOW),
  });
  assert.deepEqual(await previewInviteCode(db, created.code, "claimer", NOW), {
    state: "unknown",
  });
  assert.deepEqual(
    await claimInvite(db, { code: created.code, callerUid: "claimer", nowMs: NOW }),
    { outcome: "unknown" }
  );
  await assert.rejects(
    () => createInviteForUser(db, "creator", NOW),
    AccountUnavailableError
  );

  await db.collection("users").doc("claimer").update({
    deletionRequestedAt: admin.firestore.Timestamp.fromMillis(NOW),
  });
  for (const code of [created.code, "ZZZZZZZZZZ"]) {
    await assert.rejects(
      () => claimInvite(db, { code, callerUid: "claimer", nowMs: NOW }),
      AccountUnavailableError
    );
  }
});

test("claim validates caller state before looking up either a real or unknown code", async () => {
  await reset();
  await makeUser("creator", "mira_sky");
  await db.collection("users").doc("nameless").set({ displayName: "Sky Grid member" });

  const created = await createInviteForUser(db, "creator", NOW);

  // These must take the same caller-state error path. If the unknown code returns an
  // outcome instead, a caller with no handle can use the difference to enumerate
  // which codes exist despite the callable's no-code-dependent-errors contract.
  await assert.rejects(
    () => claimInvite(db, { code: created.code, callerUid: "nameless", nowMs: NOW }),
    MissingHandleError
  );
  await assert.rejects(
    () => claimInvite(db, { code: "ZZZZZZZZZZ", callerUid: "nameless", nowMs: NOW }),
    MissingHandleError
  );
});

test("a malformed existing pair is diagnosed and never overwritten", async () => {
  await reset();
  await makeUser("creator", "mira_sky");
  await makeUser("claimer", "theo_dawn");
  const malformedPair = {
    members: ["creator", "somebody_else"],
    status: "accepted",
    requestedBy: "creator",
    createdAt: admin.firestore.Timestamp.fromMillis(NOW - 1000),
    blockedBy: [],
  };
  await db.collection("friendships").doc("claimer_creator").set(malformedPair);

  const created = await createInviteForUser(db, "creator", NOW);
  // The callable shell catches this typed failure, emits a diagnostic containing no
  // invite code, and returns `{ outcome: "unknown" }` instead of exposing a 500.
  await assert.rejects(
    () => claimInvite(db, { code: created.code, callerUid: "claimer", nowMs: NOW }),
    MalformedFriendshipError
  );
  assert.deepEqual(
    (await db.collection("friendships").doc("claimer_creator").get()).data(),
    malformedPair
  );
  assert.equal((await db.collection("invites").doc(created.code).get()).data().status, "open");
});

test("opening the invite screen again hands back the same link instead of killing it", async () => {
  await reset();
  await makeUser("creator", "mira_sky");

  const first = await createInviteForUser(db, "creator", NOW);
  const second = await createInviteForUser(db, "creator", NOW + 60_000);

  assert.equal(second.code, first.code);
  assert.equal(second.reused, true);
  assert.equal((await db.collection("invites").get()).size, 1);
});

test("asking for a fresh link mints one and keeps the cap by revoking the oldest", async () => {
  await reset();
  await makeUser("creator", "mira_sky");

  const codes = [];
  for (let index = 0; index < 4; index += 1) {
    const created = await createInviteForUser(db, "creator", NOW + index * 1000, { fresh: true });
    codes.push(created.code);
  }

  const statuses = await Promise.all(
    codes.map(async (code) => (await db.collection("invites").doc(code).get()).data().status)
  );
  // MAX_OPEN_INVITES_PER_USER is 3: the fourth mint retires the first.
  assert.deepEqual(statuses, ["revoked", "open", "open", "open"]);
});

test("fresh creation cannot downgrade a simultaneously claimed invite", async () => {
  await reset();
  await makeUser("creator", "mira_sky");
  await makeUser("claimer", "theo_dawn");

  const links = [];
  for (let index = 0; index < 3; index += 1) {
    links.push(await createInviteForUser(db, "creator", NOW + index, { fresh: true }));
  }

  const [claimResult] = await Promise.all([
    claimInvite(db, { code: links[0].code, callerUid: "claimer", nowMs: NOW + 1000 }),
    createInviteForUser(db, "creator", NOW + 1000, { fresh: true }),
  ]);

  const oldest = (await db.collection("invites").doc(links[0].code).get()).data();
  const friendships = await db.collection("friendships").get();
  if (claimResult.outcome === "paired") {
    assert.equal(oldest.status, "claimed", "a successful claim must never be downgraded");
    assert.equal(friendships.size, 1);
  } else {
    assert.equal(claimResult.outcome, "revoked");
    assert.equal(oldest.status, "revoked");
    assert.equal(friendships.size, 0);
  }

  const all = await db.collection("invites").where("creatorUid", "==", "creator").get();
  assert.equal(all.docs.filter((document) => document.data().status === "open").length, 3);
});

test("more than fifty retained records cannot hide live links from the cap", async () => {
  await reset();
  await makeUser("creator", "mira_sky");

  const batch = db.batch();
  for (let index = 0; index < 60; index += 1) {
    const code = String(index).padStart(10, "0");
    batch.set(db.collection("invites").doc(code), {
      code,
      creatorUid: "creator",
      creatorHandle: "mira_sky",
      status: "open",
      createdAtMs: NOW - (60 - index) * 1000,
      expiresAtMs: NOW + INVITE_TTL_MS,
      expireAt: admin.firestore.Timestamp.fromMillis(NOW + 31 * 24 * 60 * 60 * 1000),
      claimedByUid: null,
      claimedAtMs: null,
      generation: 0,
    });
  }
  await batch.commit();

  const created = await createInviteForUser(db, "creator", NOW, { fresh: true });
  const all = await db.collection("invites").where("creatorUid", "==", "creator").get();
  const live = all.docs.filter((document) => document.data().status === "open");

  assert.equal(live.length, 3);
  assert.equal(live.some((document) => document.id === created.code), true);
});

test("an expired link is not handed back as reusable", async () => {
  await reset();
  await makeUser("creator", "mira_sky");

  const first = await createInviteForUser(db, "creator", NOW);
  const later = await createInviteForUser(db, "creator", NOW + INVITE_TTL_MS + 1);

  assert.notEqual(later.code, first.code);
  assert.equal(later.reused, false);
});

test("revoking answers identically for a stranger's code and a code that never existed", async () => {
  await reset();
  await makeUser("creator", "mira_sky");
  const created = await createInviteForUser(db, "creator", NOW);

  const notYours = await revokeInviteDocument(db, { code: created.code, callerUid: "stranger" });
  const notReal = await revokeInviteDocument(db, { code: "ZZZZZZZZZZ", callerUid: "stranger" });

  // Distinguishing these would make revoke a cheaper, unrated enumeration oracle than
  // preview — which is exactly how a preview-only rate limit gets bypassed.
  assert.deepEqual(notYours, notReal);
  assert.equal(
    (await db.collection("invites").doc(created.code).get()).data().status,
    "open",
    "a stranger must not be able to revoke it either"
  );
});

test("revoking is idempotent and never downgrades a claimed link", async () => {
  await reset();
  await makeUser("creator", "mira_sky");
  await makeUser("claimer", "theo_dawn");

  const open = await createInviteForUser(db, "creator", NOW);
  assert.deepEqual(await revokeInviteDocument(db, { code: open.code, callerUid: "creator" }), {
    revoked: true,
  });
  assert.deepEqual(await revokeInviteDocument(db, { code: open.code, callerUid: "creator" }), {
    revoked: true,
  });

  const spent = await createInviteForUser(db, "creator", NOW + 1000, { fresh: true });
  await claimInvite(db, { code: spent.code, callerUid: "claimer", nowMs: NOW + 1000 });
  const result = await revokeInviteDocument(db, { code: spent.code, callerUid: "creator" });

  // The friendship already exists; flipping the status would break the repeat-claim
  // path for the person who claimed it.
  assert.deepEqual(result, { revoked: false, claimed: true });
  assert.equal((await db.collection("invites").doc(spent.code).get()).data().status, "claimed");
});

test("the rate limiter stops a caller at the limit and lets the next window through", async () => {
  await reset();

  for (let index = 0; index < RATE_LIMITS.preview; index += 1) {
    assert.equal(await consumeRateLimit(db, "flooder", "preview", NOW), true, `call ${index}`);
  }
  assert.equal(await consumeRateLimit(db, "flooder", "preview", NOW), false);

  // Budgets are per action, so exhausting preview must not close claim.
  assert.equal(await consumeRateLimit(db, "flooder", "claim", NOW), true);
  // And the window really does reset.
  assert.equal(await consumeRateLimit(db, "flooder", "preview", NOW + 60 * 60 * 1000), true);
});

test("an invite records the creator's generation for the growth measurement", async () => {
  await reset();
  await makeUser("lonely", "lonely_one");
  await makeUser("social", "social_one");
  await makeUser("buddy", "buddy_one");
  await db.collection("friendships").doc("buddy_social").set({
    members: ["buddy", "social"],
    status: "accepted",
    requestedBy: "social",
    createdAt: admin.firestore.Timestamp.fromMillis(NOW - 1000),
    blockedBy: [],
  });

  const fromLonely = await createInviteForUser(db, "lonely", NOW);
  const fromSocial = await createInviteForUser(db, "social", NOW);

  assert.equal((await db.collection("invites").doc(fromLonely.code).get()).data().generation, 0);
  assert.equal((await db.collection("invites").doc(fromSocial.code).get()).data().generation, 1);
});

test("a user with no handle cannot issue a link that says who invited you", async () => {
  await reset();
  await db.collection("users").doc("nameless").set({ displayName: "Sky Grid member" });

  await assert.rejects(() => createInviteForUser(db, "nameless", NOW), /no handle/);
});

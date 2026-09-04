// Storage keeps direct reads owner-only. Buddy delivery is authorized by the
// App Check-enforced `imageDownloadURL` callable, which performs the same
// friendship/mutual-post predicate through the Admin SDK before returning a
// short-lived URL. This avoids Storage Rules' unreliable production
// Firestore cross-service lookups.
const fs = require("fs");
const path = require("path");
const assert = require("assert");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { serverTimestamp } = require("firebase/firestore");

// Must match the project the CLI launches the emulators under (see .firebaserc)
// so the Storage Rules Runtime's firestore.get()/exists() cross-service calls
// resolve against the same emulator-side Firestore data namespace as this test
// writes into via the JS SDK. A mismatched project ID here makes every
// cross-service lookup silently resolve to "not found" (see dev log).
const PROJECT_ID = "sky-grid-app";
const OWNER = "ownerUid";
const BUDDY = "buddyUid";
const STRANGER = "strangerUid";
const HANDLE_CLAIMER = "handleClaimer";
const LOCAL_DATE = "2026-07-31";

function postPath(uid = OWNER) {
  return `users/${uid}/posts/${LOCAL_DATE}`;
}

function imagePath(uid = OWNER, fileName = "abc123.jpg") {
  return `posts/${uid}/${LOCAL_DATE}/${fileName}`;
}

// `YYYY-MM-DD` for the real UTC calendar day the emulator's `request.time` falls
// on — used only by the `isRecentLocalDate` bound tests below, which need a date
// that is actually "now" rather than the fixed historical `LOCAL_DATE` fixture
// every other test in this file uses for seeded (rules-bypassed) reads.
function todayLocalDate() {
  const now = new Date();
  const yyyy = now.getUTCFullYear();
  const mm = String(now.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(now.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

function postCreateData(uid, localDate, fileName = "abc123.jpg") {
  return {
    ownerUid: uid,
    capturedAt: serverTimestamp(),
    uploadedAt: serverTimestamp(),
    imagePath: `posts/${uid}/${localDate}/${fileName}`,
    thumbPath: `posts/${uid}/${localDate}/${fileName.replace(".jpg", "_thumb.jpg")}`,
    skyColorHex: "#7EA3C8",
    minutesFromGoal: 5,
    reactions: {},
  };
}

function profileData(handle) {
  return {
    ...(handle ? { handle } : {}),
    displayName: "Sky Grid member",
    timezone: "Asia/Tokyo",
    wakeGoalMinutes: 420,
    streakCurrent: 0,
    streakLongest: 0,
    isPro: false,
    createdAt: new Date(),
  };
}

function requestData(from = OWNER, to = BUDDY, overrides = {}) {
  return {
    members: [from, to].sort(),
    status: "pending",
    requestedBy: from,
    requestedByHandle: from === OWNER ? "owner_sky" : "buddy_sky",
    recipientHandle: to === BUDDY ? "buddy_sky" : "owner_sky",
    blockedBy: [],
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

async function seedInviteIdentities() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await Promise.all([
      firestore.collection("users").doc(OWNER).set(profileData("owner_sky")),
      firestore.collection("users").doc(BUDDY).set(profileData("buddy_sky")),
      firestore.collection("handles").doc("owner_sky").set({ uid: OWNER, createdAt: new Date() }),
      firestore.collection("handles").doc("buddy_sky").set({ uid: BUDDY, createdAt: new Date() }),
    ]);
  });
}

function relationshipId(a, b) {
  return a < b ? `${a}_${b}` : `${b}_${a}`;
}

let testEnv;

async function seedFriendship(overrides = {}) {
  const id = relationshipId(OWNER, BUDDY);
  const doc = {
    members: [OWNER, BUDDY].sort(),
    status: "accepted",
    requestedBy: OWNER,
    blockedBy: [],
    createdAt: new Date(),
    ...overrides,
  };
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("friendships").doc(id).set(doc);
  });
}

async function uploadAsOwner() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const bucket = context.storage().ref(imagePath());
    await bucket.put(Buffer.from("fake-jpeg-bytes"), {
      contentType: "image/jpeg",
    });
  });
}

async function seedPost(uid, fileName = "abc123.jpg") {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(postPath(uid)).set({
      ownerUid: uid,
      imagePath: imagePath(uid, fileName),
      thumbPath: imagePath(uid, fileName.replace(".jpg", "_thumb.jpg")),
    });
  });
}

before(async function () {
  this.timeout(20000);
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8180,
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, "..", "storage.rules"), "utf8"),
      host: "127.0.0.1",
      port: 9299,
    },
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

describe("storage.rules owner-only byte access", () => {
  it("lets an owner create image bytes under their own path", async () => {
    await seedPost(OWNER);
    const ownerCtx = testEnv.authenticatedContext(OWNER);
    await assertSucceeds(
      ownerCtx.storage().ref(imagePath()).put(Buffer.from("fake-jpeg-bytes"), {
        contentType: "image/jpeg",
      })
    );
    await assertSucceeds(
      ownerCtx.storage().ref(imagePath(OWNER, "abc123_thumb.jpg")).put(Buffer.from("fake-jpeg-bytes"), {
        contentType: "image/jpeg",
      })
    );
  });

  it("lets an owner stage bytes before a Firestore post exists", async () => {
    const ownerCtx = testEnv.authenticatedContext(OWNER);
    await assertSucceeds(
      ownerCtx.storage().ref(imagePath()).put(Buffer.from("fake-jpeg-bytes"), {
        contentType: "image/jpeg",
      })
    );
  });

  it("lets an owner upload an additional private image path", async () => {
    await seedPost(OWNER);
    const ownerCtx = testEnv.authenticatedContext(OWNER);
    await assertSucceeds(
      ownerCtx.storage().ref(imagePath(OWNER, "different.jpg")).put(Buffer.from("fake-jpeg-bytes"), {
        contentType: "image/jpeg",
      })
    );
  });

  it("blocks an accepted buddy even after they post; sharing is callable-only", async () => {
    await seedFriendship({ status: "accepted" });
    await seedPost(BUDDY);
    await uploadAsOwner();
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertFails(buddyCtx.storage().ref(imagePath()).getDownloadURL());
  });

  it("blocks an accepted buddy before they post their own photo for the day", async () => {
    await seedFriendship({ status: "accepted" });
    await uploadAsOwner();
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertFails(buddyCtx.storage().ref(imagePath()).getDownloadURL());
  });

  it("lets the owner always read their own post image", async () => {
    await seedFriendship({ status: "accepted" });
    await uploadAsOwner();
    const ownerCtx = testEnv.authenticatedContext(OWNER);
    await assertSucceeds(
      ownerCtx.storage().ref(imagePath()).getDownloadURL()
    );
  });

  it("blocks a stranger with no friendship document", async () => {
    await seedFriendship({ status: "accepted" });
    await uploadAsOwner();
    const strangerCtx = testEnv.authenticatedContext(STRANGER);
    await assertFails(
      strangerCtx.storage().ref(imagePath()).getDownloadURL()
    );
  });

  it("blocks a buddy whose friendship is still pending (not accepted)", async () => {
    await seedFriendship({ status: "pending" });
    await uploadAsOwner();
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertFails(
      buddyCtx.storage().ref(imagePath()).getDownloadURL()
    );
  });

  it("blocks an accepted buddy once either side has blocked the relationship", async () => {
    await seedFriendship({ status: "accepted", blockedBy: [OWNER] });
    await uploadAsOwner();
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertFails(
      buddyCtx.storage().ref(imagePath()).getDownloadURL()
    );
  });

  it("blocks an unauthenticated read regardless of friendship state", async () => {
    await seedFriendship({ status: "accepted" });
    await uploadAsOwner();
    const anonCtx = testEnv.unauthenticatedContext();
    await assertFails(
      anonCtx.storage().ref(imagePath()).getDownloadURL()
    );
  });
});

describe("firestore.rules activeBuddy() (same predicate, Firestore side)", () => {
  it("lets an accepted buddy read the owner's profile doc", async () => {
    await seedFriendship({ status: "accepted" });
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection("users")
        .doc(OWNER)
        .set({
          handle: "owner",
          displayName: "Owner",
          timezone: "Asia/Tokyo",
          wakeGoalMinutes: 30,
          streakCurrent: 1,
          streakLongest: 1,
          isPro: false,
          createdAt: new Date(),
        });
    });
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertSucceeds(
      buddyCtx.firestore().collection("users").doc(OWNER).get()
    );
  });

  it("blocks a stranger from reading the owner's profile doc", async () => {
    await seedFriendship({ status: "accepted" });
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection("users")
        .doc(OWNER)
        .set({
          handle: "owner",
          displayName: "Owner",
          timezone: "Asia/Tokyo",
          wakeGoalMinutes: 30,
          streakCurrent: 1,
          streakLongest: 1,
          isPro: false,
          createdAt: new Date(),
        });
    });
    const strangerCtx = testEnv.authenticatedContext(STRANGER);
    await assertFails(
      strangerCtx.firestore().collection("users").doc(OWNER).get()
    );
  });

  it("blocks an accepted buddy from reading today's post before their own post", async () => {
    await seedFriendship({ status: "accepted" });
    await seedPost(OWNER);
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertFails(buddyCtx.firestore().doc(postPath()).get());
  });

  it("lets an accepted buddy read today's post after their own post", async () => {
    await seedFriendship({ status: "accepted" });
    await seedPost(OWNER);
    await seedPost(BUDDY);
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertSucceeds(buddyCtx.firestore().doc(postPath()).get());
  });
});

describe("firestore.rules posts/{localDate} create — localDate bound (2026-09-04 integrity fix)", () => {
  // Previously only `capturedAt`/`uploadedAt` were checked against server time;
  // the `localDate` path segment itself was unconstrained, so a client could
  // create a post document for an arbitrary past (or future) day — a backfilled
  // Grid cell. `isRecentLocalDate` in firestore.rules closes that.
  it("lets an owner create a post for today's actual local date", async () => {
    const ownerCtx = testEnv.authenticatedContext(OWNER);
    const localDate = todayLocalDate();
    await assertSucceeds(
      ownerCtx.firestore().doc(`users/${OWNER}/posts/${localDate}`).set(postCreateData(OWNER, localDate))
    );
  });

  it("blocks creating a post for a date years in the past", async () => {
    const ownerCtx = testEnv.authenticatedContext(OWNER);
    const localDate = "2020-01-01";
    await assertFails(
      ownerCtx.firestore().doc(`users/${OWNER}/posts/${localDate}`).set(postCreateData(OWNER, localDate))
    );
  });

  it("blocks creating a post for a date far in the future", async () => {
    const ownerCtx = testEnv.authenticatedContext(OWNER);
    const localDate = "2099-01-01";
    await assertFails(
      ownerCtx.firestore().doc(`users/${OWNER}/posts/${localDate}`).set(postCreateData(OWNER, localDate))
    );
  });

  it("blocks a non-zero-padded localDate even though it names the same real day (MEDIUM-1 fix)", async () => {
    // Without the `localDate.matches('[0-9]{4}-[0-9]{2}-[0-9]{2}')` guard, this
    // would still pass `isRecentLocalDate` (int() parses a 5-digit, leading-zero
    // year the same as the canonical 4-digit one) and create a *second*,
    // differently-keyed post document for a day that already has one — breaking
    // the one-post-per-day invariant the app relies on everywhere else
    // (Grid/streak counting, `hasPostedFor`). A leading zero on the year
    // (rather than stripping the month/day's own padding) keeps this
    // deterministically non-canonical regardless of what today's actual date
    // happens to be, unlike `Number(mm)`/`Number(dd)`, which collide with the
    // canonical string whenever the current month and day are both >= 10.
    const ownerCtx = testEnv.authenticatedContext(OWNER);
    const canonical = todayLocalDate();
    const [yyyy, mm, dd] = canonical.split("-");
    const nonCanonical = `0${yyyy}-${mm}-${dd}`;
    await assertFails(
      ownerCtx.firestore().doc(`users/${OWNER}/posts/${nonCanonical}`).set(postCreateData(OWNER, nonCanonical))
    );
  });
});

describe("firestore.rules buddy request lifecycle", () => {
  it("allows a sender to create a new deterministic pair without reading it first", async () => {
    await seedInviteIdentities();
    const firestore = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(
      firestore.collection("friendships").doc(relationshipId(OWNER, BUDDY)).set(requestData())
    );
  });

  it("still blocks reads of a pair that does not exist", async () => {
    await seedInviteIdentities();
    const firestore = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      firestore.collection("friendships").doc(relationshipId(OWNER, BUDDY)).get()
    );
  });

  it("requires the target profile to exist", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await firestore.collection("users").doc(OWNER).set(profileData("owner_sky"));
      await firestore.collection("handles").doc("owner_sky").set({ uid: OWNER, createdAt: new Date() });
      await firestore.collection("handles").doc("buddy_sky").set({ uid: BUDDY, createdAt: new Date() });
    });
    const firestore = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      firestore.collection("friendships").doc(relationshipId(OWNER, BUDDY)).set(requestData())
    );
  });

  it("rejects forged or mismatched request handles", async () => {
    await seedInviteIdentities();
    const firestore = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(
      firestore.collection("friendships").doc(relationshipId(OWNER, BUDDY)).set(
        requestData(OWNER, BUDDY, { requestedByHandle: "buddy_sky" })
      )
    );
    await assertFails(
      firestore.collection("friendships").doc(relationshipId(OWNER, BUDDY)).set(
        requestData(OWNER, BUDDY, { recipientHandle: "owner_sky" })
      )
    );
  });

  it("does not let a duplicate set overwrite an existing pending, accepted, or blocked pair", async () => {
    await seedInviteIdentities();
    const firestore = testEnv.authenticatedContext(OWNER).firestore();
    const document = firestore.collection("friendships").doc(relationshipId(OWNER, BUDDY));

    for (const existing of [
      { status: "pending" },
      { status: "accepted" },
      { status: "accepted", blockedBy: [OWNER] },
    ]) {
      await seedFriendship(existing);
      await assertFails(document.set(requestData()));
    }
  });

  it("allows only the recipient to accept a pending request", async () => {
    await seedInviteIdentities();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("friendships").doc(relationshipId(OWNER, BUDDY)).set({
        ...requestData(),
        createdAt: new Date(),
      });
    });
    const ownerDocument = testEnv.authenticatedContext(OWNER).firestore()
      .collection("friendships").doc(relationshipId(OWNER, BUDDY));
    const buddyDocument = testEnv.authenticatedContext(BUDDY).firestore()
      .collection("friendships").doc(relationshipId(OWNER, BUDDY));

    await assertFails(ownerDocument.update({ status: "accepted" }));
    await assertSucceeds(buddyDocument.update({ status: "accepted" }));
  });
});

describe("firestore.rules handle claims", () => {
  it("allows an authenticated account to create only the default initial profile", async () => {
    const firestore = testEnv.authenticatedContext(HANDLE_CLAIMER).firestore();
    await assertSucceeds(
      firestore.collection("users").doc(HANDLE_CLAIMER).set({
        displayName: "Sky Grid member",
        timezone: "Asia/Tokyo",
        wakeGoalMinutes: 420,
        streakCurrent: 0,
        streakLongest: 0,
        isPro: false,
        createdAt: serverTimestamp(),
      })
    );
  });

  it("rejects a client-created initial profile that grants Pro", async () => {
    const firestore = testEnv.authenticatedContext(HANDLE_CLAIMER).firestore();
    await assertFails(
      firestore.collection("users").doc(HANDLE_CLAIMER).set({
        displayName: "Sky Grid member",
        timezone: "Asia/Tokyo",
        wakeGoalMinutes: 420,
        streakCurrent: 0,
        streakLongest: 0,
        isPro: true,
        createdAt: serverTimestamp(),
      })
    );
  });

  it("allows a first handle and profile to be created atomically", async () => {
    const handle = "fresh_handle";
    const firestore = testEnv.authenticatedContext(HANDLE_CLAIMER).firestore();
    const batch = firestore.batch();
    batch.set(firestore.collection("handles").doc(handle), {
      uid: HANDLE_CLAIMER,
      createdAt: new Date(),
    });
    batch.set(firestore.collection("users").doc(HANDLE_CLAIMER), {
      ...profileData(handle),
      createdAt: serverTimestamp(),
    });

    await assertSucceeds(batch.commit());
  });

  it("rejects privilege fields on an atomic handle and profile create", async () => {
    const handle = "unsafe_handle";
    const firestore = testEnv.authenticatedContext(HANDLE_CLAIMER).firestore();
    const batch = firestore.batch();
    batch.set(firestore.collection("handles").doc(handle), {
      uid: HANDLE_CLAIMER,
      createdAt: new Date(),
    });
    batch.set(firestore.collection("users").doc(HANDLE_CLAIMER), {
      ...profileData(handle),
      isPro: true,
      streakCurrent: 999,
      createdAt: serverTimestamp(),
    });

    await assertFails(batch.commit());
  });

  it("rejects an invalid handle document ID", async () => {
    const handle = "Invalid Handle";
    const firestore = testEnv.authenticatedContext(HANDLE_CLAIMER).firestore();
    const batch = firestore.batch();
    batch.set(firestore.collection("handles").doc(handle), {
      uid: HANDLE_CLAIMER,
      createdAt: new Date(),
    });
    batch.set(firestore.collection("users").doc(HANDLE_CLAIMER), {
      ...profileData(handle),
      createdAt: serverTimestamp(),
    });

    await assertFails(batch.commit());
  });

  it("allows a first handle for a profile that already exists", async () => {
    const handle = "existing_profile";
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(HANDLE_CLAIMER).set(profileData());
    });

    const firestore = testEnv.authenticatedContext(HANDLE_CLAIMER).firestore();
    const batch = firestore.batch();
    batch.set(firestore.collection("handles").doc(handle), {
      uid: HANDLE_CLAIMER,
      createdAt: new Date(),
    });
    batch.update(firestore.collection("users").doc(HANDLE_CLAIMER), { handle });

    await assertSucceeds(batch.commit());
  });

  it("rejects a second handle for the same profile", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(HANDLE_CLAIMER).set(profileData("first_handle"));
      await context.firestore().collection("handles").doc("first_handle").set({
        uid: HANDLE_CLAIMER,
        createdAt: new Date(),
      });
    });

    const firestore = testEnv.authenticatedContext(HANDLE_CLAIMER).firestore();
    const batch = firestore.batch();
    batch.set(firestore.collection("handles").doc("second_handle"), {
      uid: HANDLE_CLAIMER,
      createdAt: new Date(),
    });
    batch.update(firestore.collection("users").doc(HANDLE_CLAIMER), { handle: "second_handle" });

    await assertFails(batch.commit());
  });
});

// The invite feature (Cloud Functions, 2026-08-11) keeps `invites/{code}` reachable
// only through the Admin SDK. A rule permissive enough for a recipient to read their
// own code is permissive enough for anyone signed in to read *any* code — a Firestore-
// native enumeration oracle sitting in front of no rate limiter at all. Every callable
// depends on that being impossible, so it is asserted rather than assumed.
//
// The explicit recursive matches near the bottom of firestore.rules document the
// server-only contract for both top-level documents and any future descendants.
// Firestore ORs overlapping matches, so these tests remain the real regression gate.
describe("firestore.rules invite collections are server-only", () => {
  const CODE = "ABCDE12345";

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await Promise.all([
        firestore.collection("invites").doc(CODE).set({
          code: CODE,
          creatorUid: OWNER,
          creatorHandle: "owner_handle",
          status: "open",
          createdAtMs: 1786000000000,
          expiresAtMs: 1786604800000,
          claimedByUid: null,
          generation: 0,
        }),
        firestore.collection("inviteRateLimits").doc(OWNER).set({ previewCount: 1 }),
        firestore.collection("invites").doc(CODE).collection("audit").doc("event").set({ ok: true }),
        firestore.collection("inviteRateLimits").doc(OWNER).collection("windows").doc("current").set({ count: 1 }),
      ]);
    });
  });

  it("does not let the creator read back their own invite", async () => {
    const firestore = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(firestore.collection("invites").doc(CODE).get());
  });

  it("does not let a recipient read the code they were sent", async () => {
    const firestore = testEnv.authenticatedContext(BUDDY).firestore();
    await assertFails(firestore.collection("invites").doc(CODE).get());
  });

  it("does not let anyone list the collection, which would hand over every live code", async () => {
    const firestore = testEnv.authenticatedContext(STRANGER).firestore();
    await assertFails(firestore.collection("invites").get());
  });

  it("does not let a client spend, revoke, or mint a code directly", async () => {
    const firestore = testEnv.authenticatedContext(BUDDY).firestore();
    await assertFails(
      firestore.collection("invites").doc(CODE).update({ status: "claimed", claimedByUid: BUDDY })
    );
    await assertFails(firestore.collection("invites").doc(CODE).delete());
    await assertFails(
      firestore.collection("invites").doc("ZZZZZZZZZZ").set({
        code: "ZZZZZZZZZZ",
        creatorUid: BUDDY,
        creatorHandle: "buddy_handle",
        status: "open",
        createdAtMs: 1786000000000,
        expiresAtMs: 1786604800000,
        claimedByUid: null,
        generation: 0,
      })
    );
  });

  it("does not let a caller inspect or rewrite their own rate-limit counters", async () => {
    // A client that can write this document can reset its own budget, which would
    // make the limiter decorative.
    const firestore = testEnv.authenticatedContext(OWNER).firestore();
    const counters = firestore.collection("inviteRateLimits");
    const counter = counters.doc(OWNER);
    await assertFails(counter.get());
    await assertFails(counters.get());
    await assertFails(counter.update({ previewCount: 0 }));
    await assertFails(counter.delete());
    await assertFails(counters.doc(BUDDY).set({ previewCount: 0 }));
  });

  it("does not expose either server-only namespace to unauthenticated clients", async () => {
    const firestore = testEnv.unauthenticatedContext().firestore();
    for (const collectionName of ["invites", "inviteRateLimits"]) {
      const collection = firestore.collection(collectionName);
      await assertFails(collection.doc(collectionName === "invites" ? CODE : OWNER).get());
      await assertFails(collection.get());
      await assertFails(collection.doc("new-document").set({ reset: true }));
    }
  });

  it("keeps future descendants of both server-only namespaces unreachable", async () => {
    const firestore = testEnv.authenticatedContext(OWNER).firestore();
    const descendants = [
      firestore.collection("invites").doc(CODE).collection("audit"),
      firestore.collection("inviteRateLimits").doc(OWNER).collection("windows"),
    ];

    for (const collection of descendants) {
      const existing = collection.doc(collection.id === "audit" ? "event" : "current");
      await assertFails(existing.get());
      await assertFails(collection.get());
      await assertFails(existing.update({ changed: true }));
      await assertFails(existing.delete());
      await assertFails(collection.doc("new-document").set({ created: true }));
    }
  });
});

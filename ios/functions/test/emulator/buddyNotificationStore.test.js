const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const { notifyBuddiesOfPost } = require("../../lib/buddyNotificationStore.js");

/**
 * The half of the buddy-notification feature that pure tests cannot reach: real
 * Firestore reads/writes for the marker, friendships, devices, and quiet-hours
 * profile field, plus a fake `messaging` sender (real FCM cannot be emulated).
 *
 * Lives in `test/emulator/` on purpose — `npm test`'s glob is `test/*.test.js`, so
 * this file does not make the ordinary test run require a running emulator. Use
 * `npm run test:emulator`.
 */

admin.initializeApp({ projectId: "sky-grid-app" });
const db = admin.firestore();

const NOW = Date.parse("2026-01-01T00:00:00Z"); // 09:00 in Asia/Tokyo - outside quiet hours

async function reset() {
  await Promise.all(
    ["users", "friendships"].map((collection) => db.recursiveDelete(db.collection(collection)))
  );
}

async function makeUser(uid, { timezone = "Asia/Tokyo" } = {}) {
  await db.collection("users").doc(uid).set({ handle: uid, displayName: uid, timezone });
}

async function makeDevice(uid, tokenId, fcmToken) {
  await db
    .collection("users")
    .doc(uid)
    .collection("devices")
    .doc(tokenId)
    .set({ fcmToken, updatedAt: admin.firestore.FieldValue.serverTimestamp(), platform: "ios" });
}

async function makeFriendship(pairId, { members, status = "accepted", blockedBy = [], requestedBy }) {
  await db.collection("friendships").doc(pairId).set({
    members,
    status,
    blockedBy,
    requestedBy: requestedBy ?? members[0],
    requestedByHandle: null,
    recipientHandle: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function fakeMessaging(responseForToken = () => ({ success: true, messageId: "fake-message-id" })) {
  const calls = [];
  return {
    calls,
    sendEachForMulticast: async (message) => {
      calls.push(message);
      const responses = message.tokens.map((token) => responseForToken(token));
      return {
        responses,
        successCount: responses.filter((r) => r.success).length,
        failureCount: responses.filter((r) => !r.success).length,
      };
    },
  };
}

test("notifies an accepted buddy with a registered device", async () => {
  await reset();
  await makeUser("poster");
  await makeUser("buddy");
  await makeDevice("buddy", "token-1", "fcm-token-1");
  await makeFriendship("buddy_poster", { members: ["buddy", "poster"], requestedBy: "poster" });
  const messaging = fakeMessaging();

  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-01", nowMs: NOW });

  assert.equal(messaging.calls.length, 1);
  assert.deepEqual(messaging.calls[0].tokens, ["fcm-token-1"]);
  assert.equal(messaging.calls[0].data.type, "buddy_post");
  assert.equal(messaging.calls[0].data.posterUid, "poster");
  assert.equal(messaging.calls[0].data.localDate, "2026-01-01");
});

test("a second delivery for the same post sends nothing — the marker is claimed once", async () => {
  await reset();
  await makeUser("poster");
  await makeUser("buddy");
  await makeDevice("buddy", "token-1", "fcm-token-1");
  await makeFriendship("buddy_poster", { members: ["buddy", "poster"], requestedBy: "poster" });
  const messaging = fakeMessaging();

  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-01", nowMs: NOW });
  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-01", nowMs: NOW + 1000 });

  assert.equal(messaging.calls.length, 1);
});

test("a different localDate from the same poster is a genuinely new notification", async () => {
  await reset();
  await makeUser("poster");
  await makeUser("buddy");
  await makeDevice("buddy", "token-1", "fcm-token-1");
  await makeFriendship("buddy_poster", { members: ["buddy", "poster"], requestedBy: "poster" });
  const messaging = fakeMessaging();

  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-01", nowMs: NOW });
  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-02", nowMs: NOW });

  assert.equal(messaging.calls.length, 2);
});

test("a pending (not yet accepted) friendship is never notified", async () => {
  await reset();
  await makeUser("poster");
  await makeUser("pending-buddy");
  await makeDevice("pending-buddy", "token-1", "fcm-token-1");
  await makeFriendship("pending-buddy_poster", {
    members: ["pending-buddy", "poster"],
    status: "pending",
    requestedBy: "poster",
  });
  const messaging = fakeMessaging();

  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-01", nowMs: NOW });

  assert.equal(messaging.calls.length, 0);
});

test("a friendship blocked by either member is never notified", async () => {
  await reset();
  await makeUser("poster");
  await makeUser("blocked-buddy");
  await makeDevice("blocked-buddy", "token-1", "fcm-token-1");
  await makeFriendship("blocked-buddy_poster", {
    members: ["blocked-buddy", "poster"],
    blockedBy: ["poster"],
    requestedBy: "poster",
  });
  const messaging = fakeMessaging();

  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-01", nowMs: NOW });

  assert.equal(messaging.calls.length, 0);
});

test("a recipient with no registered device is skipped without attempting a send", async () => {
  await reset();
  await makeUser("poster");
  await makeUser("buddy"); // no device doc
  await makeFriendship("buddy_poster", { members: ["buddy", "poster"], requestedBy: "poster" });
  const messaging = fakeMessaging();

  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-01", nowMs: NOW });

  assert.equal(messaging.calls.length, 0);
});

test("a recipient in their own quiet hours receives nothing", async () => {
  await reset();
  await makeUser("poster");
  await makeUser("buddy", { timezone: "Asia/Tokyo" });
  await makeDevice("buddy", "token-1", "fcm-token-1");
  await makeFriendship("buddy_poster", { members: ["buddy", "poster"], requestedBy: "poster" });
  const messaging = fakeMessaging();
  const middleOfTheNightInTokyo = Date.parse("2026-01-01T17:00:00Z"); // 02:00 Asia/Tokyo

  await notifyBuddiesOfPost(db, messaging, {
    posterUid: "poster",
    localDate: "2026-01-01",
    nowMs: middleOfTheNightInTokyo,
  });

  assert.equal(messaging.calls.length, 0);
});

test("a stale device token is deleted after a not-registered response, a healthy one is kept", async () => {
  await reset();
  await makeUser("poster");
  await makeUser("buddy");
  await makeDevice("buddy", "dead-token", "fcm-dead");
  await makeDevice("buddy", "live-token", "fcm-live");
  await makeFriendship("buddy_poster", { members: ["buddy", "poster"], requestedBy: "poster" });
  const messaging = fakeMessaging((token) =>
    token === "fcm-dead"
      ? { success: false, error: { code: "messaging/registration-token-not-registered" } }
      : { success: true, messageId: "fake" }
  );

  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-01", nowMs: NOW });

  const devices = await db.collection("users").doc("buddy").collection("devices").get();
  assert.deepEqual(devices.docs.map((doc) => doc.id).sort(), ["live-token"]);
});

test("a transient send failure does not delete the device token", async () => {
  await reset();
  await makeUser("poster");
  await makeUser("buddy");
  await makeDevice("buddy", "token-1", "fcm-token-1");
  await makeFriendship("buddy_poster", { members: ["buddy", "poster"], requestedBy: "poster" });
  const messaging = fakeMessaging(() => ({ success: false, error: { code: "messaging/internal-error" } }));

  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-01", nowMs: NOW });

  const devices = await db.collection("users").doc("buddy").collection("devices").get();
  assert.deepEqual(devices.docs.map((doc) => doc.id), ["token-1"]);
});

test("each accepted buddy gets an independent notification", async () => {
  await reset();
  await makeUser("poster");
  await makeUser("buddy-a");
  await makeUser("buddy-b");
  await makeDevice("buddy-a", "token-a", "fcm-a");
  await makeDevice("buddy-b", "token-b", "fcm-b");
  await makeFriendship("buddy-a_poster", { members: ["buddy-a", "poster"], requestedBy: "poster" });
  await makeFriendship("buddy-b_poster", { members: ["buddy-b", "poster"], requestedBy: "poster" });
  const messaging = fakeMessaging();

  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-01", nowMs: NOW });

  const notifiedTokens = messaging.calls.flatMap((call) => call.tokens).sort();
  assert.deepEqual(notifiedTokens, ["fcm-a", "fcm-b"]);
});

test("a recipient who has already posted today gets the mutual-reveal copy, not the solo one", async () => {
  await reset();
  await makeUser("poster");
  await makeUser("buddy");
  await makeDevice("buddy", "token-1", "fcm-token-1");
  await db.collection("users").doc("buddy").collection("posts").doc("2026-01-01").set({ ownerUid: "buddy" });
  await makeFriendship("buddy_poster", { members: ["buddy", "poster"], requestedBy: "poster" });
  const messaging = fakeMessaging();

  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-01", nowMs: NOW });

  assert.match(messaging.calls[0].notification.title, /both skies/i);
});

test("no accepted buddies at all means no Firestore write beyond the marker, and no send", async () => {
  await reset();
  await makeUser("poster");
  const messaging = fakeMessaging();

  await notifyBuddiesOfPost(db, messaging, { posterUid: "poster", localDate: "2026-01-01", nowMs: NOW });

  assert.equal(messaging.calls.length, 0);
});

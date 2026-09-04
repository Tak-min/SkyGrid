const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const { notifyInviterOfClaim } = require("../../lib/inviteNotificationStore.js");

/**
 * The half of the invite-claim-notification feature (closes D2) that pure tests
 * cannot reach: real Firestore reads/writes for the marker and devices, plus a
 * fake `messaging` sender. Mirrors `buddyNotificationStore.test.js`'s structure —
 * see its own header comment for why this lives under `test/emulator/`.
 */

admin.initializeApp({ projectId: "sky-grid-app" });
const db = admin.firestore();

const NOW = Date.parse("2026-01-01T00:00:00Z"); // 09:00 in Asia/Tokyo - outside quiet hours

async function reset() {
  await db.recursiveDelete(db.collection("users"));
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

test("notifies the inviter with a registered device", async () => {
  await reset();
  await makeUser("inviter");
  await makeDevice("inviter", "token-1", "fcm-token-1");
  const messaging = fakeMessaging();

  await notifyInviterOfClaim(db, messaging, {
    inviterUid: "inviter",
    pairId: "claimer_inviter",
    claimerHandle: "claimer_sky",
    nowMs: NOW,
  });

  assert.equal(messaging.calls.length, 1);
  assert.deepEqual(messaging.calls[0].tokens, ["fcm-token-1"]);
  assert.match(messaging.calls[0].notification.body, /claimer_sky/);
  assert.equal(messaging.calls[0].data.type, "invite_claimed");
});

test("a second notification for the same pair sends nothing — the marker is claimed once", async () => {
  await reset();
  await makeUser("inviter");
  await makeDevice("inviter", "token-1", "fcm-token-1");
  const messaging = fakeMessaging();
  const params = { inviterUid: "inviter", pairId: "claimer_inviter", claimerHandle: "claimer_sky", nowMs: NOW };

  await notifyInviterOfClaim(db, messaging, params);
  await notifyInviterOfClaim(db, messaging, params);

  assert.equal(messaging.calls.length, 1);
});

test("a different pairId for the same inviter is a genuinely new notification", async () => {
  await reset();
  await makeUser("inviter");
  await makeDevice("inviter", "token-1", "fcm-token-1");
  const messaging = fakeMessaging();

  await notifyInviterOfClaim(db, messaging, {
    inviterUid: "inviter",
    pairId: "claimer-one_inviter",
    claimerHandle: "one",
    nowMs: NOW,
  });
  await notifyInviterOfClaim(db, messaging, {
    inviterUid: "inviter",
    pairId: "claimer-two_inviter",
    claimerHandle: "two",
    nowMs: NOW,
  });

  assert.equal(messaging.calls.length, 2);
});

test("an inviter with no registered device is skipped without attempting a send", async () => {
  await reset();
  await makeUser("inviter");
  const messaging = fakeMessaging();

  await notifyInviterOfClaim(db, messaging, {
    inviterUid: "inviter",
    pairId: "claimer_inviter",
    claimerHandle: "claimer_sky",
    nowMs: NOW,
  });

  assert.equal(messaging.calls.length, 0);
});

test("an inviter in their own quiet hours receives nothing", async () => {
  await reset();
  await makeUser("inviter", { timezone: "Asia/Tokyo" });
  await makeDevice("inviter", "token-1", "fcm-token-1");
  const messaging = fakeMessaging();
  const midnightTokyo = Date.parse("2026-01-01T15:00:00Z"); // 00:00 in Asia/Tokyo

  await notifyInviterOfClaim(db, messaging, {
    inviterUid: "inviter",
    pairId: "claimer_inviter",
    claimerHandle: "claimer_sky",
    nowMs: midnightTokyo,
  });

  assert.equal(messaging.calls.length, 0);
});

test("a deleted inviter account is skipped without error", async () => {
  await reset();
  const messaging = fakeMessaging();

  await notifyInviterOfClaim(db, messaging, {
    inviterUid: "never-existed",
    pairId: "claimer_never-existed",
    claimerHandle: "claimer_sky",
    nowMs: NOW,
  });

  assert.equal(messaging.calls.length, 0);
});

test("a null claimerHandle falls back to generic copy instead of crashing", async () => {
  await reset();
  await makeUser("inviter");
  await makeDevice("inviter", "token-1", "fcm-token-1");
  const messaging = fakeMessaging();

  await notifyInviterOfClaim(db, messaging, {
    inviterUid: "inviter",
    pairId: "claimer_inviter",
    claimerHandle: null,
    nowMs: NOW,
  });

  assert.equal(messaging.calls.length, 1);
  assert.match(messaging.calls[0].notification.body, /Someone/);
});

test("a stale device token is deleted after a not-registered response, a healthy one is kept", async () => {
  await reset();
  await makeUser("inviter");
  await makeDevice("inviter", "stale-token", "fcm-stale");
  await makeDevice("inviter", "healthy-token", "fcm-healthy");
  const messaging = fakeMessaging((token) =>
    token === "fcm-stale"
      ? { success: false, error: { code: "messaging/registration-token-not-registered" } }
      : { success: true, messageId: "fake-message-id" }
  );

  await notifyInviterOfClaim(db, messaging, {
    inviterUid: "inviter",
    pairId: "claimer_inviter",
    claimerHandle: "claimer_sky",
    nowMs: NOW,
  });

  const devices = await db.collection("users").doc("inviter").collection("devices").listDocuments();
  const remaining = await Promise.all(devices.map((doc) => doc.id));
  assert.deepEqual(remaining.sort(), ["healthy-token"]);
});

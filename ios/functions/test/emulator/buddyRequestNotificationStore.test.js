const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const { notifyRecipientOfBuddyRequest } = require("../../lib/buddyRequestNotificationStore.js");

/**
 * The half of the buddy-request-notification feature that pure tests cannot
 * reach: real Firestore reads/writes for the marker and devices, plus a fake
 * `messaging` sender (real FCM cannot be emulated).
 *
 * Lives in `test/emulator/` on purpose — `npm test`'s glob is `test/*.test.js`, so
 * this file does not make the ordinary test run require a running emulator. Use
 * `npm run test:emulator`.
 */

admin.initializeApp({ projectId: "sky-grid-app" });
const db = admin.firestore();

const NOW = Date.parse("2026-01-01T00:00:00Z");

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

test("notifies the recipient of a buddy request with a registered device", async () => {
  await reset();
  await makeUser("recipient");
  await makeDevice("recipient", "token-1", "fcm-token-1");
  const messaging = fakeMessaging();

  await notifyRecipientOfBuddyRequest(db, messaging, {
    recipientUid: "recipient",
    pairId: "pair-1",
    requesterHandle: "requester",
    requestEventMs: NOW,
    nowMs: NOW,
  });

  assert.equal(messaging.calls.length, 1);
  assert.deepEqual(messaging.calls[0].tokens, ["fcm-token-1"]);
  assert.equal(messaging.calls[0].data.type, "buddy_request_received");
  assert.equal(messaging.calls[0].data.pairId, "pair-1");
});

test("a request → reject → re-request cycle with the same pairId notifies again, because requestEventMs differs", async () => {
  await reset();
  await makeUser("recipient");
  await makeDevice("recipient", "token-1", "fcm-token-1");
  const messaging = fakeMessaging();

  // First request.
  await notifyRecipientOfBuddyRequest(db, messaging, {
    recipientUid: "recipient",
    pairId: "pair-1",
    requesterHandle: "requester",
    requestEventMs: NOW,
    nowMs: NOW,
  });

  // Recipient rejects; `removeFriendship` deletes the friendship doc. A later
  // re-request recreates one with the same deterministic pairId, but a new
  // `createdAt` (a different requestEventMs).
  const secondRequestEventMs = NOW + 60 * 60 * 1000;
  await notifyRecipientOfBuddyRequest(db, messaging, {
    recipientUid: "recipient",
    pairId: "pair-1",
    requesterHandle: "requester",
    requestEventMs: secondRequestEventMs,
    nowMs: secondRequestEventMs,
  });

  assert.equal(messaging.calls.length, 2);
});

test("a second call with the same requestEventMs sends nothing — the marker is claimed once", async () => {
  await reset();
  await makeUser("recipient");
  await makeDevice("recipient", "token-1", "fcm-token-1");
  const messaging = fakeMessaging();

  await notifyRecipientOfBuddyRequest(db, messaging, {
    recipientUid: "recipient",
    pairId: "pair-1",
    requesterHandle: "requester",
    requestEventMs: NOW,
    nowMs: NOW,
  });
  // Same pairId AND same requestEventMs — e.g. an Eventarc redelivery/retry of
  // the very same friendship-creation event.
  await notifyRecipientOfBuddyRequest(db, messaging, {
    recipientUid: "recipient",
    pairId: "pair-1",
    requesterHandle: "requester",
    requestEventMs: NOW,
    nowMs: NOW + 1000,
  });

  assert.equal(messaging.calls.length, 1);
});

test("a recipient with no registered device is skipped without attempting a send", async () => {
  await reset();
  await makeUser("recipient"); // no device doc
  const messaging = fakeMessaging();

  await notifyRecipientOfBuddyRequest(db, messaging, {
    recipientUid: "recipient",
    pairId: "pair-1",
    requesterHandle: "requester",
    requestEventMs: NOW,
    nowMs: NOW,
  });

  assert.equal(messaging.calls.length, 0);
});

test("a deleted recipient account is skipped without attempting a send", async () => {
  await reset();
  // No user doc for "recipient" at all.
  const messaging = fakeMessaging();

  await notifyRecipientOfBuddyRequest(db, messaging, {
    recipientUid: "recipient",
    pairId: "pair-1",
    requesterHandle: "requester",
    requestEventMs: NOW,
    nowMs: NOW,
  });

  assert.equal(messaging.calls.length, 0);
});

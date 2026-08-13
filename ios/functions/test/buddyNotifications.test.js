const test = require("node:test");
const assert = require("node:assert/strict");

const {
  MAX_NOTIFIED_BUDDIES,
  activeBuddyUIDs,
  posterHandleFromFriendship,
  buddyPostNotificationCopy,
  isWithinQuietHours,
  staleTokenIndices,
  postNotificationMarkerExpireAtMs,
} = require("../lib/buddyNotifications.js");

test("activeBuddyUIDs returns only accepted, unblocked buddies of the poster", () => {
  const friendships = [
    { members: ["poster", "accepted-buddy"], status: "accepted", blockedBy: [] },
    { members: ["poster", "pending-buddy"], status: "pending", blockedBy: [] },
    { members: ["poster", "blocked-buddy"], status: "accepted", blockedBy: ["poster"] },
    { members: ["someone-else", "poster"], status: "accepted", blockedBy: [] },
  ];

  const result = activeBuddyUIDs("poster", friendships);

  assert.deepEqual(result.sort(), ["accepted-buddy", "someone-else"]);
});

test("activeBuddyUIDs excludes a friendship the poster is not even a member of", () => {
  const friendships = [{ members: ["a", "b"], status: "accepted", blockedBy: [] }];

  assert.deepEqual(activeBuddyUIDs("poster", friendships), []);
});

test("activeBuddyUIDs caps fan-out at MAX_NOTIFIED_BUDDIES", () => {
  const friendships = Array.from({ length: MAX_NOTIFIED_BUDDIES + 5 }, (_unused, index) => ({
    members: ["poster", `buddy-${index}`],
    status: "accepted",
    blockedBy: [],
  }));

  assert.equal(activeBuddyUIDs("poster", friendships).length, MAX_NOTIFIED_BUDDIES);
});

test("posterHandleFromFriendship reads the requester's own handle when they posted", () => {
  const friendship = { requestedBy: "poster", requestedByHandle: "mira_sky", recipientHandle: "theo_dawn" };

  assert.equal(posterHandleFromFriendship("poster", friendship), "mira_sky");
});

test("posterHandleFromFriendship reads the recipient's handle when the recipient posted", () => {
  const friendship = { requestedBy: "someone-else", requestedByHandle: "mira_sky", recipientHandle: "theo_dawn" };

  assert.equal(posterHandleFromFriendship("poster", friendship), "theo_dawn");
});

test("posterHandleFromFriendship falls back to null for a friendship predating handle denormalization", () => {
  const friendship = { requestedBy: "poster", requestedByHandle: null, recipientHandle: null };

  assert.equal(posterHandleFromFriendship("poster", friendship), null);
});

test("buddyPostNotificationCopy never promises a photo, only a color reveal", () => {
  const soloDirection = buddyPostNotificationCopy({ posterHandle: "mira_sky", recipientHasPostedToday: false });
  const mutual = buddyPostNotificationCopy({ posterHandle: "mira_sky", recipientHasPostedToday: true });

  assert.match(soloDirection.title, /mira_sky/);
  assert.doesNotMatch(soloDirection.body + soloDirection.title, /photo|picture|image/i);
  assert.match(mutual.body, /mira_sky/);
  assert.doesNotMatch(mutual.body + mutual.title, /photo|picture|image/i);
});

test("buddyPostNotificationCopy falls back to a generic name when the handle is unknown", () => {
  const copy = buddyPostNotificationCopy({ posterHandle: null, recipientHasPostedToday: false });

  assert.match(copy.title, /your buddy/i);
});

test("isWithinQuietHours is true inside the 22:00-05:00 local window and false outside it", () => {
  // 2026-01-01T14:00:00Z is 23:00 in Asia/Tokyo (UTC+9) - inside the window.
  const insideMs = Date.parse("2026-01-01T14:00:00Z");
  // 2026-01-01T02:00:00Z is 11:00 in Asia/Tokyo - outside the window.
  const outsideMs = Date.parse("2026-01-01T02:00:00Z");

  assert.equal(isWithinQuietHours("Asia/Tokyo", insideMs), true);
  assert.equal(isWithinQuietHours("Asia/Tokyo", outsideMs), false);
});

test("isWithinQuietHours treats the boundary hours as inclusive-start, exclusive-end", () => {
  // 2026-01-01T13:00:00Z is exactly 22:00 in Asia/Tokyo.
  const atStart = Date.parse("2026-01-01T13:00:00Z");
  // 2026-01-01T20:00:00Z is exactly 05:00 in Asia/Tokyo.
  const atEnd = Date.parse("2026-01-01T20:00:00Z");

  assert.equal(isWithinQuietHours("Asia/Tokyo", atStart), true);
  assert.equal(isWithinQuietHours("Asia/Tokyo", atEnd), false);
});

test("isWithinQuietHours fails open (sends) for a malformed or unrecognized timezone", () => {
  assert.equal(isWithinQuietHours("Not/A_Real_Zone", Date.now()), false);
  assert.equal(isWithinQuietHours("", Date.now()), false);
});

test("staleTokenIndices only flags dead-token error codes, never a transient failure", () => {
  const responses = [
    { success: true },
    { success: false, errorCode: "messaging/registration-token-not-registered" },
    { success: false, errorCode: "messaging/invalid-registration-token" },
    { success: false, errorCode: "messaging/internal-error" },
    { success: false },
  ];

  assert.deepEqual(staleTokenIndices(responses), [1, 2]);
});

test("staleTokenIndices returns nothing when every send succeeded", () => {
  assert.deepEqual(staleTokenIndices([{ success: true }, { success: true }]), []);
});

test("postNotificationMarkerExpireAtMs is strictly in the future of now", () => {
  const now = Date.now();

  assert.ok(postNotificationMarkerExpireAtMs(now) > now);
});

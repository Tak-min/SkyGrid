const test = require("node:test");
const assert = require("node:assert/strict");

const {
  inviteClaimedNotificationCopy,
  inviterUidForCreatedFriendship,
} = require("../lib/inviteNotifications.js");

test("accepted invite friendship selects requestedBy as the inviter", () => {
  const inviterUid = inviterUidForCreatedFriendship("claimer_inviter", {
    members: ["claimer", "inviter"],
    status: "accepted",
    requestedBy: "inviter",
    blockedBy: [],
  });

  assert.equal(inviterUid, "inviter");
});

test("pending handle request is not treated as a claimed invite", () => {
  const inviterUid = inviterUidForCreatedFriendship("recipient_requester", {
    members: ["recipient", "requester"],
    status: "pending",
    requestedBy: "requester",
    blockedBy: [],
  });

  assert.equal(inviterUid, null);
});

test("malformed or blocked friendships are not notified", () => {
  assert.equal(inviterUidForCreatedFriendship("claimer_inviter", { status: "accepted" }), null);
  assert.equal(inviterUidForCreatedFriendship("claimer_inviter", {
    members: ["claimer", "inviter"],
    status: "accepted",
    requestedBy: "outsider",
    blockedBy: [],
  }), null);
  assert.equal(inviterUidForCreatedFriendship("claimer_inviter", {
    members: ["claimer", "inviter"],
    status: "accepted",
    requestedBy: "inviter",
    blockedBy: ["claimer"],
  }), null);
  assert.equal(inviterUidForCreatedFriendship("wrong_pair", {
    members: ["claimer", "inviter"],
    status: "accepted",
    requestedBy: "inviter",
    blockedBy: [],
  }), null);
});

test("invite notification copy contains no account or invite identifier", () => {
  const copy = inviteClaimedNotificationCopy();

  assert.equal(copy.title, "Your invite was claimed.");
  assert.equal(copy.body, "You’re buddies now. Open Sky Grid to say hi.");
  assert.doesNotMatch(`${copy.title} ${copy.body}`, /uid|handle|code|mira_sky|claimer|inviter/i);
});

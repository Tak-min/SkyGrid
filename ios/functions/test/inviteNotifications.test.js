const test = require("node:test");
const assert = require("node:assert/strict");

const { inviteClaimedNotificationCopy } = require("../lib/inviteNotifications.js");

test("inviteClaimedNotificationCopy names the claimer by handle", () => {
  const copy = inviteClaimedNotificationCopy("mira_sky");

  assert.equal(copy.title, "Your invite was claimed.");
  assert.match(copy.body, /mira_sky/);
});

test("inviteClaimedNotificationCopy falls back to a generic name when the handle is unknown", () => {
  const copy = inviteClaimedNotificationCopy(null);

  assert.match(copy.body, /Someone/);
});

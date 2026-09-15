const test = require("node:test");
const assert = require("node:assert/strict");

const {
  buddyRequestReceivedNotificationCopy,
  buddyRequestApprovedNotificationCopy,
} = require("../lib/buddyRequestNotifications.js");

test("buddyRequestReceivedNotificationCopy includes requester's handle in English", () => {
  const copy = buddyRequestReceivedNotificationCopy({
    requesterHandle: "mira_sky",
    language: "en",
  });

  assert.match(copy.title, /mira_sky/);
  assert.match(copy.body, /open|respond/i);
});

test("buddyRequestReceivedNotificationCopy falls back to generic name when handle is null", () => {
  const copy = buddyRequestReceivedNotificationCopy({
    requesterHandle: null,
    language: "en",
  });

  assert.match(copy.title, /someone/i);
});

test("buddyRequestReceivedNotificationCopy returns Japanese copy for language: 'ja'", () => {
  const withHandle = buddyRequestReceivedNotificationCopy({
    requesterHandle: "kai",
    language: "ja",
  });
  const noHandle = buddyRequestReceivedNotificationCopy({
    requesterHandle: null,
    language: "ja",
  });

  assert.match(withHandle.title, /kaiからバディリクエスト/);
  assert.match(withHandle.body, /確認/);
  assert.match(noHandle.title, /誰か/);
});

test("buddyRequestApprovedNotificationCopy includes accepter's handle in English", () => {
  const copy = buddyRequestApprovedNotificationCopy({
    accepterHandle: "theo_dawn",
    language: "en",
  });

  assert.match(copy.title, /theo_dawn/);
  assert.match(copy.body, /buddies|together/i);
});

test("buddyRequestApprovedNotificationCopy falls back to generic name when handle is null", () => {
  const copy = buddyRequestApprovedNotificationCopy({
    accepterHandle: null,
    language: "en",
  });

  assert.match(copy.title, /your buddy/i);
});

test("buddyRequestApprovedNotificationCopy returns Japanese copy for language: 'ja'", () => {
  const withHandle = buddyRequestApprovedNotificationCopy({
    accepterHandle: "kai",
    language: "ja",
  });
  const noHandle = buddyRequestApprovedNotificationCopy({
    accepterHandle: null,
    language: "ja",
  });

  assert.match(withHandle.title, /kaiがリクエストを承認/);
  assert.match(withHandle.body, /バディになった/);
  assert.match(noHandle.title, /バディ/);
});

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  INVITE_ALPHABET,
  INVITE_CODE_LENGTH,
  INVITE_TTL_MS,
  formatInviteCode,
  generateInviteCode,
  inviteExpiresAt,
  inviteState,
  invitesToRevokeBeforeCreating,
  normalizeInviteCode,
  resolveClaim,
} = require("../lib/invites.js");

const NOW = 1_786_000_000_000;

function invite(overrides = {}) {
  const createdAtMs = overrides.createdAtMs ?? NOW;
  return {
    code: "ABCDE12345",
    creatorUid: "creator",
    creatorHandle: "mira_sky",
    status: "open",
    createdAtMs,
    expiresAtMs: inviteExpiresAt(createdAtMs),
    claimedByUid: null,
    generation: 0,
    ...overrides,
  };
}

test("the alphabet drops exactly the characters that are misread when typed", () => {
  assert.equal(INVITE_ALPHABET.length, 32);
  for (const excluded of ["I", "L", "O", "U"]) {
    assert.equal(INVITE_ALPHABET.includes(excluded), false);
  }
});

test("generates codes only from the alphabet, at the declared length", () => {
  // Every byte value maps somewhere, and `byte & 31` must never index off the end.
  for (let byte = 0; byte <= 255; byte += 1) {
    const code = generateInviteCode(() => Uint8Array.from(Array(INVITE_CODE_LENGTH).fill(byte)));
    assert.equal(code.length, INVITE_CODE_LENGTH);
    for (const character of code) {
      assert.equal(INVITE_ALPHABET.includes(character), true, `byte ${byte} produced ${character}`);
    }
  }
});

test("maps the low five bits of each byte, so the draw is unbiased", () => {
  // 256 is a whole multiple of 32, so every symbol is drawn by exactly 8 of the
  // 256 byte values. These inputs pin that: each pair differing only above bit 4
  // (0/32/64/128, 1/33/129, 31/63/255) must land on the same symbol.
  const bytes = Uint8Array.from([0, 1, 31, 32, 33, 63, 64, 255, 128, 129]);
  assert.equal(generateInviteCode(() => bytes), "01Z01Z0Z01");
});

test("refuses to build a code from short random input rather than padding it", () => {
  assert.throws(() => generateInviteCode(() => new Uint8Array(3)), /needs 10 random bytes/);
});

test("normalizes what a person can plausibly type", () => {
  assert.equal(normalizeInviteCode("abcde12345"), "ABCDE12345");
  assert.equal(normalizeInviteCode("ABCDE-12345"), "ABCDE12345");
  assert.equal(normalizeInviteCode("  ABCDE 12345 "), "ABCDE12345");
  // The three Crockford look-alikes land on the digit they are mistaken for.
  assert.equal(normalizeInviteCode("ABCDEO1234"), "ABCDE01234");
  assert.equal(normalizeInviteCode("ABCDEI2345"), "ABCDE12345");
  assert.equal(normalizeInviteCode("ABCDEl2345"), "ABCDE12345");
});

test("rejects anything that cannot be a code instead of guessing", () => {
  assert.equal(normalizeInviteCode("ABCDE1234"), null, "too short");
  assert.equal(normalizeInviteCode("ABCDE123456"), null, "too long");
  assert.equal(normalizeInviteCode("ABCDE1234!"), null, "punctuation");
  assert.equal(normalizeInviteCode("ABCDU12345"), null, "U is not in the alphabet");
  assert.equal(normalizeInviteCode(""), null);
  assert.equal(normalizeInviteCode(undefined), null);
  assert.equal(normalizeInviteCode(12345), null);
});

test("formats for display only, and the display form normalizes back", () => {
  assert.equal(formatInviteCode("ABCDE12345"), "ABCDE-12345");
  assert.equal(normalizeInviteCode(formatInviteCode("ABCDE12345")), "ABCDE12345");
});

test("an untouched link stops working on time even though nothing wrote to it", () => {
  const open = invite();
  assert.equal(inviteState(open, NOW), "open");
  assert.equal(inviteState(open, NOW + INVITE_TTL_MS - 1), "open");
  assert.equal(inviteState(open, NOW + INVITE_TTL_MS), "expired");
});

test("revocation and claiming outrank expiry when reporting state", () => {
  const past = NOW + INVITE_TTL_MS + 1;
  assert.equal(inviteState(invite({ status: "revoked" }), past), "revoked");
  assert.equal(inviteState(invite({ status: "claimed", claimedByUid: "friend" }), past), "claimed");
});

test("pairs a first-time claimant by creating the friendship", () => {
  assert.deepEqual(
    resolveClaim({ invite: invite(), nowMs: NOW, callerUid: "friend", existingFriendship: null }),
    { outcome: "paired", consumesInvite: true, friendshipAction: "create" }
  );
});

test("promotes an existing pending request rather than writing a second pair", () => {
  assert.deepEqual(
    resolveClaim({
      invite: invite(),
      nowMs: NOW,
      callerUid: "friend",
      existingFriendship: { status: "pending", isBlocked: false },
    }),
    { outcome: "paired", consumesInvite: true, friendshipAction: "promote" }
  );
});

test("a double tap answers paired again instead of claiming the code was stolen", () => {
  const claimed = invite({ status: "claimed", claimedByUid: "friend" });
  assert.deepEqual(
    resolveClaim({ invite: claimed, nowMs: NOW, callerUid: "friend", existingFriendship: null }),
    { outcome: "paired", consumesInvite: false, friendshipAction: "none" }
  );
});

test("a second person who opens a spent link is told so, and spends nothing", () => {
  const claimed = invite({ status: "claimed", claimedByUid: "friend" });
  assert.deepEqual(
    resolveClaim({ invite: claimed, nowMs: NOW, callerUid: "stranger", existingFriendship: null }),
    { outcome: "claimed", consumesInvite: false, friendshipAction: "none" }
  );
});

test("a block spends nothing, so unblocking makes the same link work again", () => {
  assert.deepEqual(
    resolveClaim({
      invite: invite(),
      nowMs: NOW,
      callerUid: "friend",
      existingFriendship: { status: "accepted", isBlocked: true },
    }),
    { outcome: "blocked", consumesInvite: false, friendshipAction: "none" }
  );
});

test("claiming your own link is refused without burning it", () => {
  assert.deepEqual(
    resolveClaim({ invite: invite(), nowMs: NOW, callerUid: "creator", existingFriendship: null }),
    { outcome: "ownInvite", consumesInvite: false, friendshipAction: "none" }
  );
});

test("expired and revoked links are refused before any friendship is considered", () => {
  const expired = resolveClaim({
    invite: invite(),
    nowMs: NOW + INVITE_TTL_MS,
    callerUid: "friend",
    existingFriendship: null,
  });
  assert.deepEqual(expired, { outcome: "expired", consumesInvite: false, friendshipAction: "none" });

  const revoked = resolveClaim({
    invite: invite({ status: "revoked" }),
    nowMs: NOW,
    callerUid: "friend",
    existingFriendship: null,
  });
  assert.deepEqual(revoked, { outcome: "revoked", consumesInvite: false, friendshipAction: "none" });
});

test("an unknown code is refused without revealing anything else", () => {
  assert.deepEqual(
    resolveClaim({ invite: null, nowMs: NOW, callerUid: "friend", existingFriendship: null }),
    { outcome: "unknown", consumesInvite: false, friendshipAction: "none" }
  );
});

test("re-claiming between people who are already buddies spends the code and adds no pair", () => {
  assert.deepEqual(
    resolveClaim({
      invite: invite(),
      nowMs: NOW,
      callerUid: "friend",
      existingFriendship: { status: "accepted", isBlocked: false },
    }),
    { outcome: "alreadyBuddies", consumesInvite: true, friendshipAction: "none" }
  );
});

test("keeps the live-link count under the cap by revoking the oldest", () => {
  const live = [
    invite({ code: "OLDEST0000", createdAtMs: NOW - 3000 }),
    invite({ code: "MIDDLE0000", createdAtMs: NOW - 2000 }),
    invite({ code: "NEWEST0000", createdAtMs: NOW - 1000 }),
  ];
  assert.deepEqual(
    invitesToRevokeBeforeCreating(live, NOW).map((each) => each.code),
    ["OLDEST0000"]
  );
  assert.deepEqual(invitesToRevokeBeforeCreating(live.slice(0, 2), NOW), []);
  assert.deepEqual(invitesToRevokeBeforeCreating([], NOW), []);
});

test("does not spend writes revoking links that are already expired", () => {
  const stale = [
    invite({ code: "STALE00000", createdAtMs: NOW - INVITE_TTL_MS - 1 }),
    invite({ code: "STALE10000", createdAtMs: NOW - INVITE_TTL_MS - 2 }),
    invite({ code: "LIVE000000", createdAtMs: NOW - 1000 }),
  ];
  assert.deepEqual(invitesToRevokeBeforeCreating(stale, NOW), []);
});

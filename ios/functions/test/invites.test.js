const test = require("node:test");
const assert = require("node:assert/strict");

const {
  INVITE_ALPHABET,
  INVITE_CODE_LENGTH,
  INVITE_LINK_BASE,
  INVITE_RETENTION_AFTER_EXPIRY_MS,
  INVITE_TTL_MS,
  FREE_CIRCLE_LIMIT,
  PRO_CIRCLE_LIMIT,
  applyCircleCap,
  existingFriendshipFrom,
  formatInviteCode,
  generateInviteCode,
  inviteDocumentFields,
  inviteExpiresAt,
  inviteFromDocument,
  inviteGeneration,
  inviteLinkURL,
  inviteState,
  inviteTTLPurgeAtMs,
  invitesToRevokeBeforeCreating,
  newestLiveInvite,
  normalizeInviteCode,
  previewState,
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

test("applyCircleCap leaves a no-op decision untouched, since nothing would grow either circle", () => {
  const decision = { outcome: "alreadyBuddies", consumesInvite: true, friendshipAction: "none" };
  assert.deepEqual(
    applyCircleCap({ decision, inviterAcceptedCount: FREE_CIRCLE_LIMIT, claimerAcceptedCount: FREE_CIRCLE_LIMIT }),
    decision
  );
});

test("applyCircleCap allows a create/promote that lands exactly at the cap", () => {
  const decision = { outcome: "paired", consumesInvite: true, friendshipAction: "create" };
  assert.deepEqual(
    applyCircleCap({
      decision,
      inviterAcceptedCount: FREE_CIRCLE_LIMIT - 1,
      claimerAcceptedCount: FREE_CIRCLE_LIMIT - 1,
    }),
    decision
  );
});

test("applyCircleCap refuses when the claimer's own circle would exceed the cap", () => {
  const decision = { outcome: "paired", consumesInvite: true, friendshipAction: "create" };
  assert.deepEqual(
    applyCircleCap({ decision, inviterAcceptedCount: 0, claimerAcceptedCount: FREE_CIRCLE_LIMIT }),
    { outcome: "circleFull", consumesInvite: false, friendshipAction: "none" }
  );
});

test("applyCircleCap refuses when the inviter's circle would exceed the cap", () => {
  const decision = { outcome: "paired", consumesInvite: true, friendshipAction: "create" };
  assert.deepEqual(
    applyCircleCap({ decision, inviterAcceptedCount: FREE_CIRCLE_LIMIT, claimerAcceptedCount: 0 }),
    { outcome: "buddyCircleFull", consumesInvite: false, friendshipAction: "none" }
  );
});

test("applyCircleCap reports the claimer's own full circle first when both sides are full", () => {
  const decision = { outcome: "paired", consumesInvite: true, friendshipAction: "promote" };
  assert.deepEqual(
    applyCircleCap({
      decision,
      inviterAcceptedCount: FREE_CIRCLE_LIMIT,
      claimerAcceptedCount: FREE_CIRCLE_LIMIT,
    }),
    { outcome: "circleFull", consumesInvite: false, friendshipAction: "none" }
  );
});

test("applyCircleCap applies Pro and Free limits independently", () => {
  const decision = { outcome: "paired", consumesInvite: true, friendshipAction: "create" };
  assert.deepEqual(
    applyCircleCap({
      decision,
      inviterAcceptedCount: PRO_CIRCLE_LIMIT - 1,
      claimerAcceptedCount: FREE_CIRCLE_LIMIT,
      limits: { inviterLimit: PRO_CIRCLE_LIMIT, claimerLimit: FREE_CIRCLE_LIMIT },
    }),
    { outcome: "circleFull", consumesInvite: false, friendshipAction: "none" }
  );
  assert.deepEqual(
    applyCircleCap({
      decision,
      inviterAcceptedCount: PRO_CIRCLE_LIMIT - 1,
      claimerAcceptedCount: PRO_CIRCLE_LIMIT - 1,
      limits: { inviterLimit: PRO_CIRCLE_LIMIT, claimerLimit: PRO_CIRCLE_LIMIT },
    }),
    decision
  );
  assert.deepEqual(
    applyCircleCap({
      decision,
      inviterAcceptedCount: PRO_CIRCLE_LIMIT,
      claimerAcceptedCount: 0,
      limits: { inviterLimit: PRO_CIRCLE_LIMIT, claimerLimit: FREE_CIRCLE_LIMIT },
    }),
    { outcome: "buddyCircleFull", consumesInvite: false, friendshipAction: "none" }
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

// --- previewInvite -----------------------------------------------------------

test("preview never contradicts claim about the same code", () => {
  // The highest-value test in this module. `previewInvite` and `claimInvite` answer
  // the same question through two different functions, and a user meets the
  // disagreement as the app lying to them: "@mira invited you" followed by "this link
  // has expired". Reordering a branch in either function fails this.
  const cases = [
    { name: "live code, stranger", invite: invite(), caller: "friend", friendship: null },
    { name: "live code, creator", invite: invite(), caller: "creator", friendship: null },
    {
      name: "expired code",
      invite: invite({ createdAtMs: NOW - INVITE_TTL_MS - 1 }),
      caller: "friend",
      friendship: null,
    },
    { name: "revoked code", invite: invite({ status: "revoked" }), caller: "friend", friendship: null },
    {
      name: "claimed by someone else",
      invite: invite({ status: "claimed", claimedByUid: "other" }),
      caller: "friend",
      friendship: null,
    },
    {
      name: "claimed by the caller",
      invite: invite({ status: "claimed", claimedByUid: "friend" }),
      caller: "friend",
      friendship: null,
    },
    { name: "no such code", invite: null, caller: "friend", friendship: null },
    {
      name: "live code, already buddies",
      invite: invite(),
      caller: "friend",
      friendship: { status: "accepted", isBlocked: false },
    },
    {
      name: "live code, blocked",
      invite: invite(),
      caller: "friend",
      friendship: { status: "accepted", isBlocked: true },
    },
  ];

  // What claim is allowed to answer, given what preview already said out loud.
  const permitted = {
    open: ["paired", "blocked", "alreadyBuddies"],
    claimedByYou: ["paired"],
    ownInvite: ["ownInvite"],
    expired: ["expired"],
    revoked: ["revoked"],
    claimed: ["claimed"],
    unknown: ["unknown"],
  };

  for (const each of cases) {
    const preview = previewState(each.invite, NOW, each.caller);
    const claim = resolveClaim({
      invite: each.invite,
      nowMs: NOW,
      callerUid: each.caller,
      existingFriendship: each.friendship,
    });
    assert.ok(
      permitted[preview].includes(claim.outcome),
      `${each.name}: preview said "${preview}" but claim answered "${claim.outcome}"`
    );
  }
});

test("preview weighs expiry ahead of who is asking, exactly as the claim does", () => {
  const lapsed = invite({ createdAtMs: NOW - INVITE_TTL_MS - 1 });
  assert.equal(previewState(lapsed, NOW, "creator"), "expired");
});

test("preview tells the person who already claimed a code that it is theirs", () => {
  const claimed = invite({ status: "claimed", claimedByUid: "friend" });
  assert.equal(previewState(claimed, NOW, "friend"), "claimedByYou");
  assert.equal(previewState(claimed, NOW, "stranger"), "claimed");
});

// --- createInvite helpers ----------------------------------------------------

test("reuses the newest live link so opening the invite screen never kills an old one", () => {
  const links = [
    invite({ code: "OLDEST0000", createdAtMs: NOW - 3000 }),
    invite({ code: "NEWEST0000", createdAtMs: NOW - 1000 }),
    invite({ code: "MIDDLE0000", createdAtMs: NOW - 2000 }),
  ];
  assert.equal(newestLiveInvite(links, NOW).code, "NEWEST0000");
});

test("a spent or lapsed link is never handed back as reusable", () => {
  const unusable = [
    invite({ code: "EXPIRED000", createdAtMs: NOW - INVITE_TTL_MS - 1 }),
    invite({ code: "CLAIMED000", status: "claimed", claimedByUid: "friend" }),
    invite({ code: "REVOKED000", status: "revoked" }),
  ];
  assert.equal(newestLiveInvite(unusable, NOW), null);
  assert.equal(newestLiveInvite([], NOW), null);
});

test("generation records a real buddy, matching the rules' definition of one", () => {
  // Same predicate as `activeBuddy()` in firestore.rules: accepted, blocked by neither.
  assert.equal(inviteGeneration([{ status: "accepted", blockedBy: [] }]), 1);
  assert.equal(inviteGeneration([{ status: "accepted", blockedBy: ["someone"] }]), 0);
  assert.equal(inviteGeneration([{ status: "pending", blockedBy: [] }]), 0);
  assert.equal(inviteGeneration([]), 0);
  assert.equal(
    inviteGeneration([
      { status: "pending", blockedBy: [] },
      { status: "accepted", blockedBy: [] },
    ]),
    1
  );
});

test("the purge instant is well after expiry, so a lapsed link can still say so", () => {
  const expiresAtMs = inviteExpiresAt(NOW);
  assert.equal(inviteTTLPurgeAtMs(expiresAtMs), expiresAtMs + INVITE_RETENTION_AFTER_EXPIRY_MS);
  assert.ok(inviteTTLPurgeAtMs(expiresAtMs) > expiresAtMs);
});

test("the share URL is built from the code alone", () => {
  assert.equal(inviteLinkURL("ABCDE12345"), `${INVITE_LINK_BASE}ABCDE12345`);
});

// --- the Firestore boundary --------------------------------------------------

test("a written invite reads back as the same record", () => {
  // Pins the write and read halves of the schema against each other. If a field is
  // renamed on one side only, this fails instead of production returning `unknown`
  // for every code ever issued.
  const fields = inviteDocumentFields({
    code: "ABCDE12345",
    creatorUid: "creator",
    creatorHandle: "mira_sky",
    createdAtMs: NOW,
    generation: 1,
  });

  assert.deepEqual(inviteFromDocument("ABCDE12345", fields), {
    code: "ABCDE12345",
    creatorUid: "creator",
    creatorHandle: "mira_sky",
    status: "open",
    createdAtMs: NOW,
    expiresAtMs: inviteExpiresAt(NOW),
    claimedByUid: null,
    generation: 1,
  });
});

test("a timestamp where a number belongs is rejected, not coerced", () => {
  // A coerced Timestamp becomes NaN, and `NaN >= expiresAtMs` is false — so the
  // invite would read as permanently unexpired. Silent immortality is the one
  // outcome this validator exists to prevent.
  const withTimestamp = {
    ...inviteDocumentFields({
      code: "ABCDE12345",
      creatorUid: "creator",
      creatorHandle: "mira_sky",
      createdAtMs: NOW,
      generation: 0,
    }),
    expiresAtMs: { _seconds: 1786000000, _nanoseconds: 0 },
  };
  assert.equal(inviteFromDocument("ABCDE12345", withTimestamp), null);
});

test("a malformed invite reads as no such code rather than as an error", () => {
  const valid = inviteDocumentFields({
    code: "ABCDE12345",
    creatorUid: "creator",
    creatorHandle: "mira_sky",
    createdAtMs: NOW,
    generation: 0,
  });

  assert.equal(inviteFromDocument("ABCDE12345", undefined), null);
  for (const field of ["creatorUid", "creatorHandle", "status", "createdAtMs", "expiresAtMs", "generation"]) {
    const missing = { ...valid };
    delete missing[field];
    assert.equal(inviteFromDocument("ABCDE12345", missing), null, `missing ${field} must not parse`);
  }
  assert.equal(inviteFromDocument("ABCDE12345", { ...valid, status: "pending" }), null);
  assert.equal(inviteFromDocument("ABCDE12345", { ...valid, generation: 2 }), null);
  assert.equal(inviteFromDocument("ABCDE12345", { ...valid, claimedByUid: 7 }), null);
  assert.equal(inviteFromDocument("ABCDE12345", { ...valid, creatorUid: "" }), null);
});

test("a document whose ID is not already canonical is refused", () => {
  // Lookup normalizes before reading, so a stored non-canonical ID is unreachable by
  // any legitimate caller and indicates the document was written by something else.
  const valid = inviteDocumentFields({
    code: "ABCDE12345",
    creatorUid: "creator",
    creatorHandle: "mira_sky",
    createdAtMs: NOW,
    generation: 0,
  });
  assert.equal(inviteFromDocument("abcde12345", valid), null);
  assert.equal(inviteFromDocument("ABCDE-12345", valid), null);
});

test("an existing pair is read only when the document really describes that pair", () => {
  const pair = {
    members: ["creator", "friend"],
    status: "pending",
    requestedBy: "creator",
    createdAt: NOW,
    blockedBy: [],
  };

  assert.deepEqual(existingFriendshipFrom(pair, "friend", "creator"), {
    status: "pending",
    isBlocked: false,
  });
  // A document for a different pair means the pair ID was computed wrongly. Reading
  // it as "no friendship" would create a duplicate.
  assert.equal(existingFriendshipFrom(pair, "friend", "stranger"), null);
  assert.equal(existingFriendshipFrom(undefined, "friend", "creator"), null);
  assert.equal(
    existingFriendshipFrom({ ...pair, members: ["creator"] }, "friend", "creator"),
    null
  );
  assert.equal(
    existingFriendshipFrom({ ...pair, members: ["friend", "creator"] }, "friend", "creator"),
    null,
    "members must stay in the order required by the rules"
  );
  assert.equal(
    existingFriendshipFrom({ ...pair, blockedBy: undefined }, "friend", "creator"),
    null,
    "activeBuddy() errors when blockedBy is not an array"
  );
  assert.equal(
    existingFriendshipFrom({ ...pair, unexpected: true }, "friend", "creator"),
    null,
    "a server promotion must not preserve keys the rules forbid"
  );
  assert.equal(
    existingFriendshipFrom({ ...pair, requestedBy: "stranger" }, "friend", "creator"),
    null
  );
  assert.equal(
    existingFriendshipFrom({ ...pair, requestedByHandle: "mira_sky" }, "friend", "creator"),
    null,
    "the two optional handle fields are an all-or-nothing pair"
  );
});

test("a block counts no matter which side made it", () => {
  const pair = {
    members: ["creator", "friend"],
    status: "accepted",
    requestedBy: "creator",
    createdAt: NOW,
  };

  for (const blocker of ["creator", "friend"]) {
    assert.equal(
      existingFriendshipFrom({ ...pair, blockedBy: [blocker] }, "friend", "creator").isBlocked,
      true,
      `a block by ${blocker} must stop the claim`
    );
  }
});

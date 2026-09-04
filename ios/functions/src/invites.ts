/**
 * Buddy invite links: code shape, expiry, and the claim decision.
 *
 * Kept free of `firebase-admin` for the same reason as `subscriptionState.ts` —
 * this is the security-critical half of the feature, and it is worth being able
 * to test every branch with `node --test` rather than only through an emulator.
 *
 * The invite exists because `friendships/{pairId}` is keyed by `sorted(uidA, uidB)`
 * (see `PairID.make` on the client, and the `create` rule in `firestore.rules`).
 * At the moment a link is *created* the second UID does not exist yet, so the
 * document ID cannot be computed and the pair cannot be pre-written. An invite is
 * the placeholder that carries the creator's identity until a second person shows
 * up, at which point both UIDs are known and the friendship can be written.
 */

/**
 * Crockford Base32: the digits and uppercase letters minus `I`, `L`, `O`, `U`.
 * `I`/`L`/`O` are dropped because they are misread as `1`/`1`/`0` when a code is
 * typed by hand from a message, and `U` because excluding it keeps accidental
 * obscenities out of generated codes. 32 symbols is exactly 5 bits per character,
 * which is what lets `generateInviteCode` stay unbiased without rejection sampling.
 */
export const INVITE_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

/** 10 symbols x 5 bits = 50 bits of entropy. */
export const INVITE_CODE_LENGTH = 10;

export const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * How long a *spent or lapsed* invite document is kept before a Firestore TTL policy
 * deletes it. This is deliberately not the same instant as `expiresAtMs`.
 *
 * If the TTL fired at expiry, two things would break. A recipient opening a stale link
 * on day 8 would be told the code never existed (`unknown`) instead of that it expired,
 * which is the difference between "ask them to send a new one" and "you typed it
 * wrong". And `resolveClaim`'s repeat-claim branch — the one that answers `paired`
 * rather than `claimed` when the same person opens their own claimed link again —
 * needs the claimed document to still be there to recognise them.
 */
export const INVITE_RETENTION_AFTER_EXPIRY_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * Built on the server so that changing the domain is a functions deploy rather than an
 * App Store release. Must stay in step with the Worker route added in step 6 of the
 * build order and with the `applinks` components in the AASA file.
 */
export const INVITE_LINK_BASE = "https://skygrid.my/i/";

/**
 * A link that is out in the world is a link that can be forwarded, so the number
 * a single person can have live at once is capped. Creating an 4th revokes the
 * oldest rather than failing: the cap is there to bound the leaked surface, not
 * to make the common "I lost the message, send me another" case an error.
 */
export const MAX_OPEN_INVITES_PER_USER = 3;

/**
 * The N-way circle cap (see `dev-notes/virality-stickiness-assessment_2026-09-04.md` §6):
 * the pairwise `friendships/{pairId}` model already supports any number of buddies per
 * user, so nothing stops an unbounded circle without a server-side limit. This is that
 * limit — a growth/product decision, not a technical one, so it lives in the callable
 * transaction rather than `firestore.rules` (Rules cannot count a user's edges without a
 * fan-out counter).
 *
 * The cap is on the count *after* the claim succeeds, not before: a user with exactly 7
 * accepted, unblocked buddies may still gain an 8th, but not a 9th. This is what "cap ~8"
 * in the design note cashes out to — 8 is the maximum circle size a claim may produce,
 * never a threshold that must already be clear beforehand.
 */
export const MAX_ACCEPTED_BUDDIES = 8;

export type InviteStatus = "open" | "claimed" | "revoked";

export interface InviteRecord {
  code: string;
  creatorUid: string;
  creatorHandle: string;
  status: InviteStatus;
  createdAtMs: number;
  expiresAtMs: number;
  claimedByUid: string | null;
  /**
   * 0 when the creator had no accepted buddy at creation time, 1 when they did.
   * A recipient's device cannot know whether the person who invited them was
   * already activated, so the server stamps it here and hands it back on claim.
   * This is what makes `K7_nextgen` countable without guessing on the client.
   */
  generation: 0 | 1;
}

/** What a caller is allowed to learn about a code without consuming it. */
export type InviteState = "open" | "expired" | "claimed" | "revoked";

/**
 * What `previewInvite` may tell a caller. A superset of `InviteState` by two cases
 * that are computed against the *caller's own* uid, so only that one caller can ever
 * observe them and neither leaks anything to anybody else.
 */
export type InvitePreviewState =
  | "open"
  | "ownInvite"
  | "claimedByYou"
  | "expired"
  | "claimed"
  | "revoked"
  | "unknown";

/** The fields of a friendship that decide whether an invite can pair two people. */
export interface FriendshipSummary {
  status: string;
  blockedBy: readonly string[];
}

export type ClaimOutcome =
  | "paired"
  | "alreadyBuddies"
  | "blocked"
  | "expired"
  | "revoked"
  | "claimed"
  | "unknown"
  | "ownInvite"
  /** The *claimer's* circle is already at `MAX_ACCEPTED_BUDDIES` — theirs to fix (remove a buddy). */
  | "circleFull"
  /** The *inviter's* circle is already at `MAX_ACCEPTED_BUDDIES`. Named after `buddyUid`/`buddyHandle`
   * on `ClaimResult`, which likewise mean "the other party, from the claimer's point of view". */
  | "buddyCircleFull";

/** What the caller's side of the pair looks like before the claim is applied. */
export interface ExistingFriendship {
  status: "pending" | "accepted";
  isBlocked: boolean;
}

export type FriendshipAction = "create" | "promote" | "none";

export interface ClaimDecision {
  outcome: ClaimOutcome;
  /** Whether this claim should mark the invite `claimed` and spend it. */
  consumesInvite: boolean;
  friendshipAction: FriendshipAction;
}

/**
 * Draws a code from `random`, which must return `length` uniformly random bytes.
 * `byte & 31` is exactly uniform over a 32-symbol alphabet because 256 is a whole
 * multiple of 32 — no modulo bias, and no rejection loop to get it wrong.
 */
export function generateInviteCode(
  random: (byteCount: number) => Uint8Array,
  length: number = INVITE_CODE_LENGTH
): string {
  const bytes = random(length);
  if (bytes.length < length) {
    throw new Error(`invite code needs ${length} random bytes, got ${bytes.length}`);
  }
  let code = "";
  for (let index = 0; index < length; index += 1) {
    code += INVITE_ALPHABET[bytes[index] & 31];
  }
  return code;
}

/**
 * Accepts what a person can plausibly type or paste and returns the canonical
 * code, or `null` if it cannot be one. Case is folded, the display hyphen and any
 * stray whitespace are dropped, and the three Crockford look-alikes are mapped to
 * the digit they are mistaken for — someone reading `SKY0-1` off a screen may
 * well type `SKYO-l`.
 */
export function normalizeInviteCode(raw: string): string | null {
  if (typeof raw !== "string") return null;
  let normalized = "";
  for (const character of raw.toUpperCase()) {
    if (character === "-" || character === " " || character === "\t") continue;
    const mapped = character === "O" ? "0" : character === "I" || character === "L" ? "1" : character;
    if (!INVITE_ALPHABET.includes(mapped)) return null;
    normalized += mapped;
  }
  return normalized.length === INVITE_CODE_LENGTH ? normalized : null;
}

/** `XXXXX-XXXXX` — only ever for display, never for storage or lookup. */
export function formatInviteCode(code: string): string {
  const half = Math.floor(code.length / 2);
  return `${code.slice(0, half)}-${code.slice(half)}`;
}

export function inviteExpiresAt(createdAtMs: number): number {
  return createdAtMs + INVITE_TTL_MS;
}

/**
 * Expiry is evaluated ahead of status so a link that was never opened stops
 * working on time even though nothing ever wrote to it.
 */
export function inviteState(invite: InviteRecord, nowMs: number): InviteState {
  if (invite.status === "revoked") return "revoked";
  if (invite.status === "claimed") return "claimed";
  return nowMs >= invite.expiresAtMs ? "expired" : "open";
}

/**
 * The whole claim decision, with no I/O. The caller applies it inside one
 * Firestore transaction so the friendship write and the invite spend land
 * together or not at all.
 *
 * Two branches deliberately do *not* spend the invite:
 *
 * - A repeat claim by the person who already claimed it answers `paired` instead
 *   of `claimed`. A double tap, a retried network call, or reopening the same
 *   message must not tell someone their own successful pairing was stolen.
 * - A block spends nothing, so unblocking makes the original link work again
 *   rather than stranding the pair with a burnt code.
 */
export function resolveClaim(input: {
  invite: InviteRecord | null;
  nowMs: number;
  callerUid: string;
  existingFriendship: ExistingFriendship | null;
}): ClaimDecision {
  const { invite, nowMs, callerUid, existingFriendship } = input;

  if (!invite) return { outcome: "unknown", consumesInvite: false, friendshipAction: "none" };

  const state = inviteState(invite, nowMs);
  if (state === "revoked") return { outcome: "revoked", consumesInvite: false, friendshipAction: "none" };
  if (state === "expired") return { outcome: "expired", consumesInvite: false, friendshipAction: "none" };
  if (state === "claimed") {
    return invite.claimedByUid === callerUid
      ? { outcome: "paired", consumesInvite: false, friendshipAction: "none" }
      : { outcome: "claimed", consumesInvite: false, friendshipAction: "none" };
  }

  if (invite.creatorUid === callerUid) {
    return { outcome: "ownInvite", consumesInvite: false, friendshipAction: "none" };
  }

  if (existingFriendship?.isBlocked) {
    return { outcome: "blocked", consumesInvite: false, friendshipAction: "none" };
  }
  if (existingFriendship?.status === "accepted") {
    return { outcome: "alreadyBuddies", consumesInvite: true, friendshipAction: "none" };
  }
  if (existingFriendship?.status === "pending") {
    return { outcome: "paired", consumesInvite: true, friendshipAction: "promote" };
  }
  return { outcome: "paired", consumesInvite: true, friendshipAction: "create" };
}

/**
 * Overrides a `create`/`promote` decision with a refusal when either side's circle would
 * exceed `MAX_ACCEPTED_BUDDIES` after this claim. Kept as a second, pure function rather
 * than folded into `resolveClaim` because the counts it needs come from two extra
 * Firestore queries that only the `friendshipAction !== "none"` branch ever needs to run —
 * `claimInvite` calls `resolveClaim` first and only pays for those reads, and for this
 * check, when there is an edge to actually cap.
 *
 * `*AcceptedCount` is the count *before* this claim (accepted and unblocked friendships,
 * i.e. what `firestore.rules`' `activeBuddy()` would also treat as a real buddy) — the
 * `+ 1` below accounts for the edge this claim is about to create or promote.
 *
 * Checked in a fixed order — claimer's circle before the inviter's — because a claimer
 * whose own circle is full has an immediate remedy (remove one of their own buddies) that
 * an inviter's fullness does not offer them, so it is the more actionable thing to report
 * first when (rarely) both are true at once.
 */
export function applyCircleCap(input: {
  decision: ClaimDecision;
  inviterAcceptedCount: number;
  claimerAcceptedCount: number;
}): ClaimDecision {
  const { decision, inviterAcceptedCount, claimerAcceptedCount } = input;
  if (decision.friendshipAction === "none") return decision;

  if (claimerAcceptedCount + 1 > MAX_ACCEPTED_BUDDIES) {
    return { outcome: "circleFull", consumesInvite: false, friendshipAction: "none" };
  }
  if (inviterAcceptedCount + 1 > MAX_ACCEPTED_BUDDIES) {
    return { outcome: "buddyCircleFull", consumesInvite: false, friendshipAction: "none" };
  }
  return decision;
}

/**
 * The oldest open invites to revoke so that creating one more stays within
 * `MAX_OPEN_INVITES_PER_USER`. Expired invites are ignored: they already fail
 * `inviteState`, so spending writes on them would be noise.
 */
export function invitesToRevokeBeforeCreating(
  openInvites: readonly InviteRecord[],
  nowMs: number,
  limit: number = MAX_OPEN_INVITES_PER_USER
): InviteRecord[] {
  const live = openInvites
    .filter((invite) => inviteState(invite, nowMs) === "open")
    .sort((first, second) => first.createdAtMs - second.createdAtMs);
  const excess = live.length - (limit - 1);
  return excess > 0 ? live.slice(0, excess) : [];
}

/**
 * What `previewInvite` answers. Branch order mirrors `resolveClaim` exactly, so the
 * two can never disagree about the same code — a preview that says "open" followed by
 * a claim that says "expired" would be a bug the user experiences as the app lying.
 * `test/invites.test.js` asserts that agreement as a property rather than trusting
 * this comment.
 *
 * `claimedByYou` exists for the same reason `resolveClaim` answers `paired` on a
 * repeat claim: someone who taps their own link twice must not be told their pairing
 * was taken by a stranger.
 */
export function previewState(
  invite: InviteRecord | null,
  nowMs: number,
  callerUid: string
): InvitePreviewState {
  if (!invite) return "unknown";

  const state = inviteState(invite, nowMs);
  if (state === "revoked") return "revoked";
  if (state === "expired") return "expired";
  if (state === "claimed") {
    return invite.claimedByUid === callerUid ? "claimedByYou" : "claimed";
  }
  return invite.creatorUid === callerUid ? "ownInvite" : "open";
}

/**
 * The most recently created still-open invite, or `null`.
 *
 * `createInvite` hands this back instead of minting a new code every time the invite
 * screen is opened. Minting unconditionally would combine with
 * `invitesToRevokeBeforeCreating` to silently revoke a link the user had already sent
 * someone — the fourth screen-open would kill the first link. Reuse makes opening the
 * screen idempotent and free; an explicit "get a new link" still mints.
 */
export function newestLiveInvite(
  openInvites: readonly InviteRecord[],
  nowMs: number
): InviteRecord | null {
  const live = openInvites.filter((invite) => inviteState(invite, nowMs) === "open");
  if (live.length === 0) return null;
  return live.reduce((newest, invite) => (invite.createdAtMs > newest.createdAtMs ? invite : newest));
}

/**
 * Whether the creator already had a real buddy when they made this link — 0 or 1,
 * stamped at creation because the recipient's device has no way to know it.
 *
 * "Real" is the same predicate as `activeBuddy()` in `firestore.rules` and
 * `isActiveBuddy` in `index.ts`: accepted, and blocked by neither side. This is its
 * third occurrence, which is exactly why it is a named function with tests rather
 * than a fourth inline `&&` chain.
 */
export function inviteGeneration(friendships: readonly FriendshipSummary[]): 0 | 1 {
  const hasActiveBuddy = friendships.some(
    (friendship) => friendship.status === "accepted" && friendship.blockedBy.length === 0
  );
  return hasActiveBuddy ? 1 : 0;
}

export function inviteLinkURL(code: string, base: string = INVITE_LINK_BASE): string {
  return `${base}${code}`;
}

export function inviteTTLPurgeAtMs(expiresAtMs: number): number {
  return expiresAtMs + INVITE_RETENTION_AFTER_EXPIRY_MS;
}

/**
 * The complete stored form of a new invite, so that the document written and the
 * `InviteRecord` read back are defined in one place and cannot drift.
 *
 * `expireAt` is not here: it is a Firestore `Timestamp`, which this module stays free
 * of on purpose. The caller derives it from `inviteTTLPurgeAtMs`.
 */
export function inviteDocumentFields(input: {
  code: string;
  creatorUid: string;
  creatorHandle: string;
  createdAtMs: number;
  generation: 0 | 1;
}): InviteRecord & { claimedAtMs: number | null } {
  return {
    code: input.code,
    creatorUid: input.creatorUid,
    creatorHandle: input.creatorHandle,
    status: "open",
    createdAtMs: input.createdAtMs,
    expiresAtMs: inviteExpiresAt(input.createdAtMs),
    claimedByUid: null,
    generation: input.generation,
    claimedAtMs: null,
  };
}

/**
 * Validates raw Firestore data at the boundary. Returns `null` rather than throwing,
 * because a malformed invite must read as "no such code" and not as a 500 that tells
 * an enumerator they found something unusual.
 *
 * The timestamp fields are required to be numbers and are never coerced. A `Timestamp`
 * object arriving here would coerce to `NaN` in every comparison, and `NaN >= x` is
 * `false` — so a coerced invite would read as permanently *unexpired*, which is the
 * one failure mode this validator exists to make impossible.
 */
export function inviteFromDocument(
  id: string,
  data: Record<string, unknown> | undefined
): InviteRecord | null {
  if (!data) return null;
  if (normalizeInviteCode(id) !== id) return null;

  const status = data.status;
  if (status !== "open" && status !== "claimed" && status !== "revoked") return null;

  const generation = data.generation;
  if (generation !== 0 && generation !== 1) return null;

  const createdAtMs = data.createdAtMs;
  const expiresAtMs = data.expiresAtMs;
  if (!Number.isFinite(createdAtMs) || !Number.isFinite(expiresAtMs)) return null;

  const creatorUid = data.creatorUid;
  const creatorHandle = data.creatorHandle;
  if (typeof creatorUid !== "string" || creatorUid.length === 0) return null;
  if (typeof creatorHandle !== "string" || creatorHandle.length === 0) return null;

  const claimedByUid = data.claimedByUid;
  if (claimedByUid !== null && typeof claimedByUid !== "string") return null;

  return {
    code: id,
    creatorUid,
    creatorHandle,
    status,
    createdAtMs: createdAtMs as number,
    expiresAtMs: expiresAtMs as number,
    claimedByUid: (claimedByUid as string | null) ?? null,
    generation,
  };
}

/**
 * The caller's side of an existing pair, as `resolveClaim` wants it. `null` when there
 * is no friendship, or when the document does not describe *this* pair — a mismatch
 * means the caller computed the wrong pair ID, and treating that as "no friendship"
 * would create a second one.
 */
export function existingFriendshipFrom(
  data: Record<string, unknown> | undefined,
  callerUid: string,
  creatorUid: string
): ExistingFriendship | null {
  if (!data) return null;

  const allowedKeys = new Set([
    "members",
    "status",
    "requestedBy",
    "requestedByHandle",
    "recipientHandle",
    "createdAt",
    "blockedBy",
  ]);
  const requiredKeys = ["members", "status", "requestedBy", "createdAt", "blockedBy"];
  const keys = Object.keys(data);
  if (keys.some((key) => !allowedKeys.has(key))) return null;
  if (requiredKeys.some((key) => !Object.hasOwn(data, key))) return null;

  const members = data.members;
  if (!Array.isArray(members) || members.length !== 2) return null;
  const expectedMembers = [callerUid, creatorUid].sort();
  if (members[0] !== expectedMembers[0] || members[1] !== expectedMembers[1]) return null;

  const status = data.status;
  if (status !== "pending" && status !== "accepted") return null;

  const requestedBy = data.requestedBy;
  if (typeof requestedBy !== "string" || !expectedMembers.includes(requestedBy)) return null;

  const blockedBy = data.blockedBy;
  if (!Array.isArray(blockedBy)) return null;
  if (blockedBy.some((uid) => typeof uid !== "string" || !expectedMembers.includes(uid))) return null;
  if (new Set(blockedBy).size !== blockedBy.length) return null;

  const hasRequestedByHandle = Object.hasOwn(data, "requestedByHandle");
  const hasRecipientHandle = Object.hasOwn(data, "recipientHandle");
  if (hasRequestedByHandle !== hasRecipientHandle) return null;
  if (hasRequestedByHandle) {
    const handlePattern = /^[a-z0-9_]{3,20}$/;
    if (
      typeof data.requestedByHandle !== "string"
      || !handlePattern.test(data.requestedByHandle)
      || typeof data.recipientHandle !== "string"
      || !handlePattern.test(data.recipientHandle)
    ) {
      return null;
    }
  }

  // Either side blocking is a block: the invite must not resurrect a pair that one of
  // them deliberately severed, regardless of which one did it.
  const isBlocked = blockedBy.length > 0;

  return { status, isBlocked };
}

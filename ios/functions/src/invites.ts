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
 * A link that is out in the world is a link that can be forwarded, so the number
 * a single person can have live at once is capped. Creating an 4th revokes the
 * oldest rather than failing: the cap is there to bound the leaked surface, not
 * to make the common "I lost the message, send me another" case an error.
 */
export const MAX_OPEN_INVITES_PER_USER = 3;

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

export type ClaimOutcome =
  | "paired"
  | "alreadyBuddies"
  | "blocked"
  | "expired"
  | "revoked"
  | "claimed"
  | "unknown"
  | "ownInvite";

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

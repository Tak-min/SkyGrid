import { randomBytes } from "node:crypto";
import { Timestamp, type Firestore } from "firebase-admin/firestore";
import {
  INVITE_LINK_BASE,
  type ClaimOutcome,
  type FriendshipSummary,
  type InviteRecord,
  existingFriendshipFrom,
  generateInviteCode,
  inviteDocumentFields,
  inviteFromDocument,
  inviteGeneration,
  inviteLinkURL,
  invitesToRevokeBeforeCreating,
  inviteTTLPurgeAtMs,
  newestLiveInvite,
  normalizeInviteCode,
  previewState,
  resolveClaim,
  type InvitePreviewState,
} from "./invites.js";
import {
  RATE_LIMITS,
  RATE_LIMIT_WINDOW_MS,
  rateLimitDecision,
  type RateLimitedAction,
} from "./rateLimit.js";

/**
 * Every Firestore access the invite feature makes.
 *
 * `db` is a parameter rather than a call to `admin.firestore()` inside, and nothing
 * here throws `HttpsError`. Both are deliberate: it makes this module runnable against
 * the Firestore emulator on its own, without Functions, Auth, or App Check — which is
 * the only way the claim transaction's concurrency behaviour can be tested at all.
 * `index.ts` is the thin shell that adds identity, validation, and error mapping.
 *
 * **Never log a whole invite code.** Document IDs *are* the secrets here, so a stray
 * `logger.info({ code })` would publish live invites to anyone with log access and
 * bypass the rate limiter entirely. `codeForLog` exists for this.
 */

const INVITES = "invites";
const RATE_LIMITS_COLLECTION = "inviteRateLimits";
const FRIENDSHIPS = "friendships";
const USERS = "users";

/** Rate-limit documents are disposable; two days outlives any one-hour window. */
const RATE_LIMIT_RETENTION_MS = 2 * 24 * 60 * 60 * 1000;

/** A collision on 50 bits is ~1-in-a-billion; three failures means the RNG is broken. */
const MAX_CODE_ATTEMPTS = 3;

/** Enough to identify a code across log lines, far too little to use one. */
export function codeForLog(code: string): string {
  return `${code.slice(0, 4)}…`;
}

export function rateLimitDocumentPath(uid: string): string {
  return `${RATE_LIMITS_COLLECTION}/${uid}`;
}

/**
 * The order-independent `friendships/{pairId}`. Must agree with `PairID.make` on the
 * client and `relationshipId()` in `firestore.rules` — all three compute the same
 * string, which is what lets either member find the pair without a lookup.
 */
export function pairID(first: string, second: string): string {
  return first < second ? `${first}_${second}` : `${second}_${first}`;
}

/**
 * Consumes one unit of the caller's budget and reports whether the call may proceed.
 *
 * Counted *before* the invite is read, and counted identically whether or not the code
 * turns out to exist. If a successful lookup were exempt, the difference between
 * "rate limited" and "answered" would itself become the existence oracle the limiter
 * is meant to close.
 *
 * Non-transactional on purpose. A read-modify-write transaction on one hot document
 * aborts under contention, which would turn an attacker's flood into 500s that we
 * then retry. This degrades into latency instead, and Firestore's ~1 write/sec/document
 * ceiling then acts as a second limiter we did not have to build. The cost is that a
 * concurrent burst can overshoot by roughly the number of in-flight requests — fine
 * for a cost bound, and the reason the limits are not sized as a security boundary.
 */
export async function consumeRateLimit(
  db: Firestore,
  uid: string,
  action: RateLimitedAction,
  nowMs: number
): Promise<boolean> {
  const reference = db.collection(RATE_LIMITS_COLLECTION).doc(uid);
  const snapshot = await reference.get();
  const data = snapshot.data();

  const startKey = `${action}WindowStartMs`;
  const countKey = `${action}Count`;
  const storedStart = data?.[startKey];
  const storedCount = data?.[countKey];
  const current =
    typeof storedStart === "number" && typeof storedCount === "number"
      ? { windowStartMs: storedStart, count: storedCount }
      : null;

  const decision = rateLimitDecision(current, nowMs, RATE_LIMIT_WINDOW_MS, RATE_LIMITS[action]);
  if (!decision.nextWindow) return false;

  await reference.set(
    {
      [startKey]: decision.nextWindow.windowStartMs,
      [countKey]: decision.nextWindow.count,
      expireAt: Timestamp.fromMillis(nowMs + RATE_LIMIT_RETENTION_MS),
    },
    { merge: true }
  );
  return decision.allowed;
}

export interface PreviewResult {
  state: InvitePreviewState;
  creatorHandle?: string;
  expiresAtMs?: number;
}

/**
 * What a caller may learn about a code without spending it.
 *
 * `creatorHandle` is returned only in the states where the caller can already act on
 * the code, and a handle is not a secret in the first place — `firestore.rules` lets
 * any signed-in user read `handles/{handle}`. So this discloses a mapping, to someone
 * who already holds a live code, i.e. to the person it was sent to.
 */
export async function previewInviteCode(
  db: Firestore,
  code: string,
  callerUid: string,
  nowMs: number
): Promise<PreviewResult> {
  const invite = await readInvite(db, code);
  const state = previewState(invite, nowMs, callerUid);

  if (!invite || state === "expired" || state === "claimed" || state === "revoked") {
    return { state };
  }
  return { state, creatorHandle: invite.creatorHandle, expiresAtMs: invite.expiresAtMs };
}

export async function readInvite(db: Firestore, code: string): Promise<InviteRecord | null> {
  const snapshot = await db.collection(INVITES).doc(code).get();
  return inviteFromDocument(snapshot.id, snapshot.data());
}

export interface CreateInviteResult {
  code: string;
  expiresAtMs: number;
  url: string;
  /** True when an already-live link was handed back rather than a new one minted. */
  reused: boolean;
}

/** The creator has no profile or no handle — `previewInvite` would have nothing to show. */
export class MissingHandleError extends Error {}
/** The RNG produced `MAX_CODE_ATTEMPTS` colliding codes. Infrastructure, not user state. */
export class CodeExhaustionError extends Error {}

/**
 * Returns the caller's live invite link, minting one only when needed.
 *
 * `fresh` forces a new code. Without the reuse default, opening the invite screen four
 * times would mint four codes and `invitesToRevokeBeforeCreating` would revoke the
 * first — silently killing a link the user had already sent someone. Reuse makes
 * opening the screen idempotent and free.
 */
export async function createInviteForUser(
  db: Firestore,
  uid: string,
  nowMs: number,
  options: { fresh?: boolean } = {}
): Promise<CreateInviteResult> {
  const [user, friendships, ownInvites] = await Promise.all([
    db.collection(USERS).doc(uid).get(),
    db.collection(FRIENDSHIPS).where("members", "array-contains", uid).get(),
    // Deliberately filtered on `creatorUid` alone and narrowed in memory. Adding
    // `status == "open"` would make this a compound query, and a missing composite
    // index is invisible in the emulator and fails 100% of the time in production.
    // The cap keeps the result to a handful of documents either way.
    db.collection(INVITES).where("creatorUid", "==", uid).limit(50).get(),
  ]);

  const handle = user.data()?.handle;
  if (!user.exists || typeof handle !== "string" || handle.length === 0) {
    throw new MissingHandleError("The caller has no handle.");
  }

  const own = ownInvites.docs
    .map((document) => inviteFromDocument(document.id, document.data()))
    .filter((invite): invite is InviteRecord => invite !== null);

  if (options.fresh !== true) {
    const live = newestLiveInvite(own, nowMs);
    if (live) {
      return {
        code: live.code,
        expiresAtMs: live.expiresAtMs,
        url: inviteLinkURL(live.code, INVITE_LINK_BASE),
        reused: true,
      };
    }
  }

  const summaries: FriendshipSummary[] = friendships.docs.map((document) => {
    const data = document.data();
    return {
      status: typeof data.status === "string" ? data.status : "",
      blockedBy: Array.isArray(data.blockedBy) ? data.blockedBy : [],
    };
  });
  const generation = inviteGeneration(summaries);
  const toRevoke = invitesToRevokeBeforeCreating(own, nowMs);

  for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt += 1) {
    const code = generateInviteCode((byteCount) => randomBytes(byteCount));
    const fields = inviteDocumentFields({
      code,
      creatorUid: uid,
      creatorHandle: handle,
      createdAtMs: nowMs,
      generation,
    });

    const batch = db.batch();
    // Re-applied on every attempt, which is safe because `revoked` is a constant
    // rather than an increment.
    for (const stale of toRevoke) {
      batch.update(db.collection(INVITES).doc(stale.code), { status: "revoked" });
    }
    // `create`, never `set`: on the ~1-in-a-billion collision, `set` would hand two
    // people the same code and overwrite a stranger's live invite.
    batch.create(db.collection(INVITES).doc(code), {
      ...fields,
      expireAt: Timestamp.fromMillis(inviteTTLPurgeAtMs(fields.expiresAtMs)),
    });

    try {
      await batch.commit();
      return {
        code,
        expiresAtMs: fields.expiresAtMs,
        url: inviteLinkURL(code, INVITE_LINK_BASE),
        reused: false,
      };
    } catch (error: unknown) {
      if (!isAlreadyExists(error)) throw error;
    }
  }

  throw new CodeExhaustionError("Could not draw an unused invite code.");
}

function isAlreadyExists(error: unknown): boolean {
  // gRPC status 6 = ALREADY_EXISTS.
  return (error as { code?: number })?.code === 6;
}

export interface ClaimResult {
  outcome: ClaimOutcome;
  pairId?: string;
  buddyUid?: string;
  buddyHandle?: string;
  generation?: 0 | 1;
}

/**
 * Spends a code and creates the friendship, atomically.
 *
 * This is the reason the feature is a callable at all. The two writes — the pair, and
 * marking the code spent — must land together or not at all; leaving that to the
 * client makes griefing trivial (claim the pair, never spend the code, or the reverse).
 *
 * **The friendship is written as `accepted` even though `firestore.rules` forces a
 * client-created one to be `pending`.** That rule encodes a limit on *client
 * authority*: a client cannot assert the other party's consent. The server has both
 * consents in hand — the creator minted the link, the claimer opened it — so it writes
 * the fixed point of a sequence the rules already allow (create pending, then the
 * other member flips it to accepted). Every intermediate state is legal; only the
 * atomicity is new.
 *
 * Every *other* rule constraint is satisfied, and that is not tidiness. `activeBuddy()`
 * in `firestore.rules` calls `relationship.data.blockedBy.size()`; a friendship written
 * without `blockedBy` makes that expression error, and a rules error denies the read —
 * silently breaking buddy reads for the *other* member, in code this feature never
 * touches. The rules are the only written schema this collection has.
 */
export async function claimInvite(
  db: Firestore,
  input: { code: string; callerUid: string; nowMs: number }
): Promise<ClaimResult> {
  const { code, callerUid, nowMs } = input;

  return db.runTransaction(async (transaction) => {
    const inviteReference = db.collection(INVITES).doc(code);
    const inviteSnapshot = await transaction.get(inviteReference);
    const invite = inviteFromDocument(inviteSnapshot.id, inviteSnapshot.data());

    // Without a creator UID the pair ID cannot be computed, so there is nothing
    // further to read. This is forced by the data model, not an optimisation.
    if (!invite) return { outcome: "unknown" as const };

    const pairId = pairID(invite.creatorUid, callerUid);
    const [friendshipSnapshot, callerSnapshot, creatorSnapshot] = await transaction.getAll(
      db.collection(FRIENDSHIPS).doc(pairId),
      db.collection(USERS).doc(callerUid),
      db.collection(USERS).doc(invite.creatorUid)
    );

    const callerHandle = callerSnapshot.data()?.handle;
    if (!callerSnapshot.exists || typeof callerHandle !== "string" || callerHandle.length === 0) {
      throw new MissingHandleError("The caller has no handle.");
    }

    // The creator deleted their account, so the link is genuinely dead. Reported as
    // `unknown` rather than a distinct state: it is indistinguishable from a bad code
    // from the claimer's side, and it keeps the rules' `exists(users/{other})`
    // constraint satisfied.
    const creatorHandle = creatorSnapshot.data()?.handle;
    if (!creatorSnapshot.exists || typeof creatorHandle !== "string" || creatorHandle.length === 0) {
      return { outcome: "unknown" as const };
    }

    const existingFriendship = friendshipSnapshot.exists
      ? existingFriendshipFrom(friendshipSnapshot.data(), callerUid, invite.creatorUid)
      : null;
    // An existing document that does not parse is a bug, not a user state. Failing
    // loudly beats writing a second pair on top of it.
    if (friendshipSnapshot.exists && !existingFriendship) {
      throw new Error(`friendships/${pairId} exists but does not describe this pair`);
    }

    const decision = resolveClaim({ invite, nowMs, callerUid, existingFriendship });

    if (decision.friendshipAction === "create") {
      const members = [invite.creatorUid, callerUid].sort();
      transaction.create(db.collection(FRIENDSHIPS).doc(pairId), {
        members,
        status: "accepted",
        requestedBy: invite.creatorUid,
        requestedByHandle: creatorHandle,
        recipientHandle: callerHandle,
        createdAt: Timestamp.fromMillis(nowMs),
        blockedBy: [],
      });
    } else if (decision.friendshipAction === "promote") {
      // Only the status. The handles on an old pending document are not backfilled:
      // an accepted buddy is rendered from `users/{uid}`, so they would be write-only
      // data and a fourth diff shape nobody validates.
      transaction.update(db.collection(FRIENDSHIPS).doc(pairId), { status: "accepted" });
    }

    if (decision.consumesInvite) {
      transaction.update(inviteReference, {
        status: "claimed",
        claimedByUid: callerUid,
        claimedAtMs: nowMs,
      });
    }

    if (decision.outcome !== "paired" && decision.outcome !== "alreadyBuddies") {
      return { outcome: decision.outcome };
    }
    return {
      outcome: decision.outcome,
      pairId,
      buddyUid: invite.creatorUid,
      buddyHandle: creatorHandle,
      generation: invite.generation,
    };
  });
}

export interface RevokeResult {
  revoked: boolean;
  /** Only ever set after the ownership check passes, so it leaks nothing. */
  claimed?: boolean;
}

/**
 * Takes one of the caller's own links out of circulation.
 *
 * **"Not yours" and "no such code" must return the identical value.** Distinguishing
 * them would make this a cheaper, unlimited enumeration oracle than `previewInvite` —
 * which is precisely how a preview-only rate limit gets bypassed. That uniformity is
 * also why this call needs no rate limit of its own.
 *
 * A claimed invite is never downgraded to revoked: the friendship already exists, and
 * flipping the status would break `resolveClaim`'s repeat-claim idempotency for the
 * person who claimed it.
 */
export async function revokeInviteDocument(
  db: Firestore,
  input: { code: string; callerUid: string }
): Promise<RevokeResult> {
  const reference = db.collection(INVITES).doc(input.code);
  const snapshot = await reference.get();
  const invite = inviteFromDocument(snapshot.id, snapshot.data());

  if (!invite || invite.creatorUid !== input.callerUid) return { revoked: false };
  if (invite.status === "claimed") return { revoked: false, claimed: true };
  if (invite.status === "revoked") return { revoked: true };

  await reference.update({ status: "revoked" });
  return { revoked: true };
}

/** Normalizes at the boundary; `null` for anything that cannot be a code. */
export function canonicalCode(raw: unknown): string | null {
  return typeof raw === "string" ? normalizeInviteCode(raw) : null;
}

export const INVITE_COLLECTION = INVITES;
export const INVITE_RATE_LIMIT_COLLECTION = RATE_LIMITS_COLLECTION;

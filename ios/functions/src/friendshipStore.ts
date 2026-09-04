import { Timestamp, type Firestore, type QuerySnapshot } from "firebase-admin/firestore";
import {
  MAX_ACCEPTED_BUDDIES,
  applyCircleCap,
  existingFriendshipFrom,
  type ClaimDecision,
} from "./invites.js";
import { AccountUnavailableError, MalformedFriendshipError, pairID } from "./inviteStore.js";

const FRIENDSHIPS = "friendships";
const HANDLES = "handles";
const USERS = "users";

export type BuddyRequestOutcome =
  | "sent"
  | "alreadyPending"
  | "incomingRequestExists"
  | "alreadyBuddies"
  | "blocked"
  | "unknownHandle"
  | "ownHandle";

export type BuddyAcceptOutcome =
  | "accepted"
  | "alreadyAccepted"
  | "circleFull"
  | "buddyCircleFull"
  | "invalidRequest";

function validHandle(handle: unknown): handle is string {
  return typeof handle === "string" && /^[a-z0-9_]{3,20}$/.test(handle);
}

function countUnblockedAcceptedFriendships(snapshot: QuerySnapshot): number {
  return snapshot.docs.filter((document) => {
    const data = document.data();
    return data.status === "accepted" && Array.isArray(data.blockedBy) && data.blockedBy.length === 0;
  }).length;
}

/**
 * Server authority for the handle-based pending-request path.
 *
 * Firestore Rules cannot count a user's accepted edges. Leaving this write client-side
 * would therefore leave a permanent bypass around `claimInvite`'s circle cap. The
 * callable also makes the immutable pair shape once, from verified handle mappings,
 * rather than accepting either UID or handle as a client assertion.
 */
export async function requestBuddyByHandle(
  db: Firestore,
  input: { callerUid: string; recipientHandle: string; nowMs: number },
): Promise<{ outcome: BuddyRequestOutcome }> {
  const { callerUid, recipientHandle, nowMs } = input;
  if (!validHandle(recipientHandle)) return { outcome: "unknownHandle" };

  return db.runTransaction(async (transaction) => {
    const [callerSnapshot, handleSnapshot] = await transaction.getAll(
      db.collection(USERS).doc(callerUid),
      db.collection(HANDLES).doc(recipientHandle),
    );
    const callerData = callerSnapshot.data();
    if (
      !callerSnapshot.exists
      || Object.hasOwn(callerData ?? {}, "deletionRequestedAt")
      || !validHandle(callerData?.handle)
    ) {
      throw new AccountUnavailableError("The caller has no usable handle.");
    }
    const recipientUid = handleSnapshot.data()?.uid;
    if (typeof recipientUid !== "string") return { outcome: "unknownHandle" as const };
    if (recipientUid === callerUid) return { outcome: "ownHandle" as const };

    const [recipientSnapshot, friendshipSnapshot] = await transaction.getAll(
      db.collection(USERS).doc(recipientUid),
      db.collection(FRIENDSHIPS).doc(pairID(callerUid, recipientUid)),
    );
    const recipientData = recipientSnapshot.data();
    if (
      !recipientSnapshot.exists
      || Object.hasOwn(recipientData ?? {}, "deletionRequestedAt")
      || recipientData?.handle !== recipientHandle
    ) {
      return { outcome: "unknownHandle" as const };
    }

    if (!friendshipSnapshot.exists) {
      transaction.create(friendshipSnapshot.ref, {
        members: [callerUid, recipientUid].sort(),
        status: "pending",
        requestedBy: callerUid,
        requestedByHandle: callerData.handle,
        recipientHandle,
        createdAt: Timestamp.fromMillis(nowMs),
        blockedBy: [],
      });
      return { outcome: "sent" as const };
    }

    const existing = existingFriendshipFrom(friendshipSnapshot.data(), callerUid, recipientUid);
    if (!existing) throw new MalformedFriendshipError("Existing friendship data is malformed.");
    if (existing.isBlocked) return { outcome: "blocked" as const };
    if (existing.status === "accepted") return { outcome: "alreadyBuddies" as const };
    return {
      outcome: friendshipSnapshot.data()?.requestedBy === callerUid
        ? "alreadyPending"
        : "incomingRequestExists",
    };
  });
}

/**
 * Server authority for accepting a pending handle-based request. Both accepted-circle
 * counts are read in the same transaction as the promotion, so concurrent accepts
 * cannot each independently create a ninth edge.
 */
export async function acceptBuddyRequest(
  db: Firestore,
  input: { callerUid: string; pairId: string },
): Promise<{ outcome: BuddyAcceptOutcome }> {
  const { callerUid, pairId } = input;

  return db.runTransaction(async (transaction) => {
    const friendshipRef = db.collection(FRIENDSHIPS).doc(pairId);
    const friendshipSnapshot = await transaction.get(friendshipRef);
    const data = friendshipSnapshot.data();
    const members = data?.members;
    const requestedBy = data?.requestedBy;

    if (
      !friendshipSnapshot.exists
      || !Array.isArray(members)
      || members.length !== 2
      || typeof members[0] !== "string"
      || typeof members[1] !== "string"
      || members[0] >= members[1]
      || pairID(members[0], members[1]) !== pairId
      || !members.includes(callerUid)
      || typeof requestedBy !== "string"
      || !members.includes(requestedBy)
    ) {
      return { outcome: "invalidRequest" as const };
    }

    if (data?.status === "accepted") return { outcome: "alreadyAccepted" as const };
    if (data?.status !== "pending" || requestedBy === callerUid || !Array.isArray(data?.blockedBy) || data.blockedBy.length > 0) {
      return { outcome: "invalidRequest" as const };
    }

    const requesterUid = requestedBy;
    const acceptedQuery = (uid: string) => transaction.get(
      db.collection(FRIENDSHIPS).where("members", "array-contains", uid).where("status", "==", "accepted"),
    );
    const [requesterFriendships, callerFriendships] = await Promise.all([
      acceptedQuery(requesterUid),
      acceptedQuery(callerUid),
    ]);

    const decision: ClaimDecision = applyCircleCap({
      decision: { outcome: "paired", consumesInvite: false, friendshipAction: "promote" },
      inviterAcceptedCount: countUnblockedAcceptedFriendships(requesterFriendships),
      claimerAcceptedCount: countUnblockedAcceptedFriendships(callerFriendships),
    });
    if (decision.outcome === "circleFull" || decision.outcome === "buddyCircleFull") {
      return { outcome: decision.outcome };
    }

    transaction.update(friendshipRef, { status: "accepted" });
    return { outcome: "accepted" as const };
  });
}

export { MAX_ACCEPTED_BUDDIES };

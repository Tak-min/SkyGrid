import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import type { Messaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { isWithinQuietHours, staleTokenIndices } from "./buddyNotifications.js";
import { inviteClaimedNotificationCopy } from "./inviteNotifications.js";

/**
 * Notifies an inviter the moment their invite link is claimed (closes D2). Called
 * synchronously from `claimInviteCode` right after `claimInvite`'s transaction
 * commits with a `"paired"` outcome — deliberately *not* a separate
 * `onDocumentCreated` Firestore trigger on `friendships/{pairId}` the way
 * `onBuddyPostCreated` is: that collection's documents are created both by an
 * invite claim (`status: "accepted"` immediately) and by an ordinary handle-based
 * friend request (`status: "pending"`, accepted later via a *different* client
 * write this module has nothing to do with) — see `firestore.rules`' "buddy
 * request lifecycle" and `inviteStore.ts#claimInvite`'s own doc comment. A
 * document-create trigger cannot tell those two origins apart without re-deriving
 * exactly the context `claimInvite`'s caller already has for free (was this
 * literally the result of a claim, and who is the inviter), so calling this
 * directly from the callable is simpler and cannot misfire for the unrelated flow.
 *
 * **Never throws** — same discipline as `notifyBuddiesOfPost`: the pairing already
 * succeeded and committed by the time this runs, and nothing about a notification
 * failing may ever surface as if the claim itself had failed.
 */

const USERS = "users";
const DEVICES = "devices";
const INVITE_CLAIM_NOTIFICATION_MARKERS = "inviteClaimNotifications";
const MAX_TOKENS_PER_RECIPIENT = 10;
const FIRESTORE_ALREADY_EXISTS_CODE = 6;

/** Mirrors `POST_NOTIFICATION_MARKER_RETENTION_MS`'s reasoning in `buddyNotifications.ts`. */
const INVITE_CLAIM_NOTIFICATION_MARKER_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;

export interface NotifyInviterOfClaimParams {
  inviterUid: string;
  pairId: string;
  claimerHandle: string | null;
  nowMs: number;
}

export async function notifyInviterOfClaim(
  db: Firestore,
  messaging: Pick<Messaging, "sendEachForMulticast">,
  params: NotifyInviterOfClaimParams
): Promise<void> {
  const { inviterUid, pairId, claimerHandle, nowMs } = params;

  // `pairId` (one per ordered pair of accounts, see `PairID`/the Swift-side
  // equivalent) rather than the claimer's uid: idempotent per *relationship*, so a
  // retried callable invocation (a client timing out and re-sending the exact same
  // already-succeeded claim) never sends a second notification for the same pair,
  // while a genuinely different claimer pairing with the same inviter later still
  // gets their own marker.
  if (!(await claimNotificationMarker(db, inviterUid, pairId, nowMs))) {
    logger.info("Invite-claim notification already claimed for this pair; skipping.", { inviterUid, pairId });
    return;
  }

  let inviterDoc;
  let devicesSnapshot;
  try {
    [inviterDoc, devicesSnapshot] = await Promise.all([
      db.collection(USERS).doc(inviterUid).get(),
      db
        .collection(USERS)
        .doc(inviterUid)
        .collection(DEVICES)
        .orderBy("updatedAt", "desc")
        .limit(MAX_TOKENS_PER_RECIPIENT)
        .get(),
    ]);
  } catch (error: unknown) {
    logger.error("Could not read inviter data for an invite-claim notification.", { inviterUid, error });
    return;
  }

  // The inviter's account was deleted between the claim committing and here.
  if (!inviterDoc.exists) return;

  const timezone = inviterDoc.data()?.timezone;
  if (typeof timezone === "string" && isWithinQuietHours(timezone, nowMs)) return;

  const tokens = devicesSnapshot.docs
    .map((doc) => doc.data().fcmToken as string | undefined)
    .filter((token): token is string => Boolean(token));
  if (tokens.length === 0) return;

  const copy = inviteClaimedNotificationCopy(claimerHandle);

  let response;
  try {
    response = await messaging.sendEachForMulticast({
      tokens,
      notification: { title: copy.title, body: copy.body },
      data: { type: "invite_claimed", pairId },
      apns: {
        headers: { "apns-collapse-id": collapseId(pairId) },
        payload: { aps: { sound: "default", "thread-id": "invite-claimed" } },
      },
    });
  } catch (error: unknown) {
    logger.error("Invite-claim notification send failed.", { inviterUid, error });
    return;
  }

  const staleIndices = staleTokenIndices(
    response.responses.map((entry) => ({ success: entry.success, errorCode: entry.error?.code }))
  );
  if (staleIndices.length === 0) return;

  const writer = db.bulkWriter();
  for (const index of staleIndices) {
    writer.delete(devicesSnapshot.docs[index].ref);
  }
  await writer.close();
}

/** `false` means a marker already existed — the caller must not send anything. */
async function claimNotificationMarker(
  db: Firestore,
  inviterUid: string,
  pairId: string,
  nowMs: number
): Promise<boolean> {
  const markerRef = db.collection(USERS).doc(inviterUid).collection(INVITE_CLAIM_NOTIFICATION_MARKERS).doc(pairId);
  try {
    await markerRef.create({
      createdAt: FieldValue.serverTimestamp(),
      expireAt: Timestamp.fromMillis(nowMs + INVITE_CLAIM_NOTIFICATION_MARKER_RETENTION_MS),
    });
    return true;
  } catch (error: unknown) {
    if (isAlreadyExistsError(error)) return false;
    logger.error("Could not claim the invite-claim notification marker.", { inviterUid, pairId, error });
    return false;
  }
}

/** `apns-collapse-id` is capped at 64 bytes by APNs; a pairId never gets close, but
 * the cap is enforced defensively rather than assumed (mirrors `buddyNotificationStore.ts`). */
function collapseId(pairId: string): string {
  return `ic_${pairId}`.slice(0, 64);
}

function isAlreadyExistsError(error: unknown): boolean {
  const code = (error as { code?: unknown })?.code;
  return code === FIRESTORE_ALREADY_EXISTS_CODE || code === "already-exists";
}

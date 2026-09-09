import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import type { Messaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { isWithinQuietHours, staleTokenIndices } from "./buddyNotifications.js";
import { inviteClaimedNotificationCopy } from "./inviteNotifications.js";

/**
 * Notifies only the inviter after an invite claim establishes a friendship.
 * The Firestore create trigger and the callable's pending-to-accepted fallback share
 * this shell and its marker, so at most one path sends for a relationship.
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
  nowMs: number;
}

export async function notifyInviterOfClaim(
  db: Firestore,
  messaging: Pick<Messaging, "sendEachForMulticast">,
  params: NotifyInviterOfClaimParams
): Promise<void> {
  const { inviterUid, pairId, nowMs } = params;

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

  const copy = inviteClaimedNotificationCopy();

  let response;
  try {
    response = await messaging.sendEachForMulticast({
      tokens,
      notification: { title: copy.title, body: copy.body },
      data: { type: "invite_claimed" },
      apns: {
        headers: { "apns-collapse-id": "invite_claimed" },
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

function isAlreadyExistsError(error: unknown): boolean {
  const code = (error as { code?: unknown })?.code;
  return code === FIRESTORE_ALREADY_EXISTS_CODE || code === "already-exists";
}

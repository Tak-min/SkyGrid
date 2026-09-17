import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import type { Messaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import {
  deviceLanguageFromDoc,
  staleTokenIndices,
} from "./buddyNotifications.js";
import {
  buddyRequestReceivedNotificationCopy,
  buddyRequestApprovedNotificationCopy,
} from "./buddyRequestNotifications.js";

/**
 * Handles all Firestore/FCM operations for buddy request notifications.
 * Both (a) request received and (b) request approved use this module.
 * Transient FCM send failures are thrown after releasing the marker lease, allowing
 * the Firestore trigger to retry without duplicating a successful delivery.
 */

const USERS = "users";
const FRIENDSHIPS = "friendships";
const DEVICES = "devices";
const BUDDY_REQUEST_NOTIFICATION_MARKERS = "buddyRequestNotifications";
const MAX_TOKENS_PER_RECIPIENT = 10;
const FIRESTORE_ALREADY_EXISTS_CODE = 6;

/** Mirrors the retention window used by other notification markers. */
const BUDDY_REQUEST_NOTIFICATION_MARKER_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;

export interface NotifyRecipientOfBuddyRequestParams {
  recipientUid: string;
  pairId: string;
  requesterHandle: string | null;
  /** The friendship document's `createdAt`, in ms — see the doc comment on
   * `claimNotificationMarker` for why this, not just `pairId`, is part of the
   * marker key. */
  requestEventMs: number;
  nowMs: number;
}

/**
 * Notifies the RECIPIENT when a handle-based buddy request is received.
 */
export async function notifyRecipientOfBuddyRequest(
  db: Firestore,
  messaging: Pick<Messaging, "sendEachForMulticast">,
  params: NotifyRecipientOfBuddyRequestParams
): Promise<void> {
  const { recipientUid, pairId, requesterHandle, requestEventMs, nowMs } = params;

  let recipientDoc;
  let devicesSnapshot;
  try {
    [recipientDoc, devicesSnapshot] = await Promise.all([
      db.collection(USERS).doc(recipientUid).get(),
      db
        .collection(USERS)
        .doc(recipientUid)
        .collection(DEVICES)
        .orderBy("updatedAt", "desc")
        .limit(MAX_TOKENS_PER_RECIPIENT)
        .get(),
    ]);
  } catch (error: unknown) {
    logger.error("Could not read recipient data for a buddy request notification.", { recipientUid, error });
    return;
  }

  // The recipient's account was deleted.
  if (!recipientDoc.exists) return;

  // Deliberately NOT quiet-hours-gated, unlike the recurring daily post
  // notification: this is a one-shot event with no later retry, so dropping it
  // during 22:00-05:00 would silence it forever rather than just delaying it,
  // which is a worse outcome than one off-hours push for an event this rare.

  type EligibleDevice = { ref: FirebaseFirestore.DocumentReference; token: string; language: ReturnType<typeof deviceLanguageFromDoc> };
  const eligibleDevices: EligibleDevice[] = devicesSnapshot.docs
    .map((doc) => {
      const token = doc.data().fcmToken as string | undefined;
      if (!token) return null;
      return { ref: doc.ref, token, language: deviceLanguageFromDoc(doc.data().language) };
    })
    .filter((entry): entry is EligibleDevice => entry !== null);
  if (eligibleDevices.length === 0) return;

  const staleRefs: FirebaseFirestore.DocumentReference[] = [];
  let anyRetryableFailure = false;
  for (const language of ["en", "ja"] as const) {
    const group = eligibleDevices.filter((device) => device.language === language);
    if (group.length === 0) continue;

    if (!(await claimNotificationMarker(db, recipientUid, pairId, "request_received", requestEventMs, language, nowMs))) {
      logger.info("Buddy request received notification already claimed for this pair/event/language; skipping.", {
        recipientUid,
        pairId,
        language,
      });
      continue;
    }

    const copy = buddyRequestReceivedNotificationCopy({
      requesterHandle,
      language,
    });

    let response;
    try {
      response = await messaging.sendEachForMulticast({
        tokens: group.map((device) => device.token),
        notification: { title: copy.title, body: copy.body },
        data: { type: "buddy_request_received", pairId },
        apns: {
          headers: { "apns-collapse-id": `br_${pairId}`.slice(0, 64) },
          payload: { aps: { sound: "default", "thread-id": "buddy-request" } },
        },
      });
    } catch (error: unknown) {
      const permanent = isPermanentFcmError(error);
      logger.error("Buddy request received notification send failed.", { recipientUid, language, permanent, error });
      await finishNotificationMarker(db, recipientUid, pairId, "request_received", requestEventMs, language, permanent);
      if (!permanent) anyRetryableFailure = true;
      continue;
    }

    const staleIndices = staleTokenIndices(
      response.responses.map((entry) => ({ success: entry.success, errorCode: entry.error?.code }))
    );
    const delivered = response.successCount > 0;
    await finishNotificationMarker(db, recipientUid, pairId, "request_received", requestEventMs, language, delivered);
    if (!delivered && staleIndices.length < response.responses.length) {
      anyRetryableFailure = true;
    }
    for (const index of staleIndices) {
      staleRefs.push(group[index].ref);
    }
  }
  if (staleRefs.length > 0) {
    const writer = db.bulkWriter();
    for (const ref of staleRefs) {
      writer.delete(ref);
    }
    await writer.close();
  }
  if (anyRetryableFailure) {
    throw new Error(`Buddy request received notification had a retryable send failure for pair ${pairId}.`);
  }
}

export interface NotifyRequesterOfBuddyApprovalParams {
  requesterUid: string;
  pairId: string;
  accepterHandle: string | null;
  /** The friendship document's `acceptedAt`, in ms — see the doc comment on
   * `claimNotificationMarker` for why this, not just `pairId`, is part of the
   * marker key. */
  requestEventMs: number;
  nowMs: number;
}

/**
 * Notifies the REQUESTER when their pending buddy request is accepted.
 */
export async function notifyRequesterOfBuddyApproval(
  db: Firestore,
  messaging: Pick<Messaging, "sendEachForMulticast">,
  params: NotifyRequesterOfBuddyApprovalParams
): Promise<void> {
  const { requesterUid, pairId, accepterHandle, requestEventMs, nowMs } = params;

  let requesterDoc;
  let devicesSnapshot;
  try {
    [requesterDoc, devicesSnapshot] = await Promise.all([
      db.collection(USERS).doc(requesterUid).get(),
      db
        .collection(USERS)
        .doc(requesterUid)
        .collection(DEVICES)
        .orderBy("updatedAt", "desc")
        .limit(MAX_TOKENS_PER_RECIPIENT)
        .get(),
    ]);
  } catch (error: unknown) {
    logger.error("Could not read requester data for a buddy request approval notification.", { requesterUid, error });
    return;
  }

  // The requester's account was deleted.
  if (!requesterDoc.exists) return;

  // See the matching comment in notifyRecipientOfBuddyRequest — this is a
  // one-shot event with no retry, so it is not quiet-hours-gated.

  type EligibleDevice = { ref: FirebaseFirestore.DocumentReference; token: string; language: ReturnType<typeof deviceLanguageFromDoc> };
  const eligibleDevices: EligibleDevice[] = devicesSnapshot.docs
    .map((doc) => {
      const token = doc.data().fcmToken as string | undefined;
      if (!token) return null;
      return { ref: doc.ref, token, language: deviceLanguageFromDoc(doc.data().language) };
    })
    .filter((entry): entry is EligibleDevice => entry !== null);
  if (eligibleDevices.length === 0) return;

  const staleRefs: FirebaseFirestore.DocumentReference[] = [];
  let anyRetryableFailure = false;
  for (const language of ["en", "ja"] as const) {
    const group = eligibleDevices.filter((device) => device.language === language);
    if (group.length === 0) continue;

    if (!(await claimNotificationMarker(db, requesterUid, pairId, "request_approved", requestEventMs, language, nowMs))) {
      logger.info("Buddy request approved notification already claimed for this pair/event/language; skipping.", {
        requesterUid,
        pairId,
        language,
      });
      continue;
    }

    const copy = buddyRequestApprovedNotificationCopy({
      accepterHandle,
      language,
    });

    let response;
    try {
      response = await messaging.sendEachForMulticast({
        tokens: group.map((device) => device.token),
        notification: { title: copy.title, body: copy.body },
        data: { type: "buddy_request_approved", pairId },
        apns: {
          headers: { "apns-collapse-id": `ba_${pairId}`.slice(0, 64) },
          payload: { aps: { sound: "default", "thread-id": "buddy-request" } },
        },
      });
    } catch (error: unknown) {
      const permanent = isPermanentFcmError(error);
      logger.error("Buddy request approved notification send failed.", { requesterUid, language, permanent, error });
      await finishNotificationMarker(db, requesterUid, pairId, "request_approved", requestEventMs, language, permanent);
      if (!permanent) anyRetryableFailure = true;
      continue;
    }

    const staleIndices = staleTokenIndices(
      response.responses.map((entry) => ({ success: entry.success, errorCode: entry.error?.code }))
    );
    const delivered = response.successCount > 0;
    await finishNotificationMarker(db, requesterUid, pairId, "request_approved", requestEventMs, language, delivered);
    if (!delivered && staleIndices.length < response.responses.length) {
      anyRetryableFailure = true;
    }
    for (const index of staleIndices) {
      staleRefs.push(group[index].ref);
    }
  }
  if (staleRefs.length > 0) {
    const writer = db.bulkWriter();
    for (const ref of staleRefs) {
      writer.delete(ref);
    }
    await writer.close();
  }
  if (anyRetryableFailure) {
    throw new Error(`Buddy request approved notification had a retryable send failure for pair ${pairId}.`);
  }
}

/**
 * Claims a short-lived send lease; a successful send is finalized separately.
 *
 * The marker key includes `requestEventMs` (the friendship doc's `createdAt`
 * for a received request, `acceptedAt` for an approval) and `language`, not
 * just `pairId`. `pairId` alone is stable across a reject-then-re-request
 * cycle — `removeFriendship` deletes the friendship document, and a later
 * request recreates one with the same deterministic pair ID — so a marker
 * keyed only on `pairId` stayed "sent" from the first request and silently
 * suppressed the notification for every subsequent request to the same pair
 * within the 7-day retention window. Folding in the event's own timestamp
 * gives each request/approval its own marker while still deduplicating
 * retries of that same event (the timestamp is stable across retries).
 */
async function claimNotificationMarker(
  db: Firestore,
  uid: string,
  pairId: string,
  notificationType: "request_received" | "request_approved",
  requestEventMs: number,
  language: string,
  nowMs: number
): Promise<boolean> {
  const markerRef = db
    .collection(USERS)
    .doc(uid)
    .collection(BUDDY_REQUEST_NOTIFICATION_MARKERS)
    .doc(`${pairId}_${notificationType}_${requestEventMs}_${language}`);
  try {
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(markerRef);
      const data = existing.data();
      if (existing.exists && data?.state === "sent") throw new Error("already-sent");
      const activeLease = data?.state === "sending"
        && data.leaseUntil instanceof Timestamp
        && data.leaseUntil.toMillis() > nowMs;
      if (activeLease) throw new Error("already-sending");
      const payload = {
        createdAt: data?.createdAt ?? FieldValue.serverTimestamp(),
        expireAt: Timestamp.fromMillis(nowMs + BUDDY_REQUEST_NOTIFICATION_MARKER_RETENTION_MS),
        state: "sending",
        leaseUntil: Timestamp.fromMillis(nowMs + 5 * 60 * 1000),
      };
      if (existing.exists) transaction.update(markerRef, payload);
      else transaction.create(markerRef, payload);
    });
    return true;
  } catch (error: unknown) {
    if (error instanceof Error && (error.message === "already-sent" || error.message === "already-sending")) return false;
    if (isAlreadyExistsError(error)) return false;
    logger.error("Could not claim the buddy request notification marker.", { uid, pairId, notificationType, error });
    return false;
  }
}

/** `sent: true` also covers a permanent (non-retryable) FCM error — see
 * `isPermanentFcmError` and the matching comment in `buddyNotificationStore.ts`. */
async function finishNotificationMarker(
  db: Firestore,
  uid: string,
  pairId: string,
  notificationType: "request_received" | "request_approved",
  requestEventMs: number,
  language: string,
  sent: boolean,
): Promise<void> {
  const markerRef = db
    .collection(USERS)
    .doc(uid)
    .collection(BUDDY_REQUEST_NOTIFICATION_MARKERS)
    .doc(`${pairId}_${notificationType}_${requestEventMs}_${language}`);
  try {
    if (sent) await markerRef.update({ state: "sent", leaseUntil: null });
    else await markerRef.delete();
  } catch (error: unknown) {
    logger.error("Could not finalize the buddy request notification marker.", {
      uid,
      pairId,
      notificationType,
      language,
      sent,
      error,
    });
  }
}

const PERMANENT_FCM_ERROR_CODES = new Set([
  "messaging/invalid-argument",
  "messaging/invalid-recipient",
  "messaging/mismatched-credential",
  "messaging/sender-id-mismatch",
  "messaging/third-party-auth-error",
  "messaging/authentication-error",
]);

/** Mirrors `buddyNotificationStore.ts`'s helper of the same name — kept as a
 * separate copy rather than a shared import so each store's retry policy can
 * diverge later without coordinating a shared module. */
function isPermanentFcmError(error: unknown): boolean {
  const code = (error as { code?: unknown })?.code;
  return typeof code === "string" && PERMANENT_FCM_ERROR_CODES.has(code);
}

function isAlreadyExistsError(error: unknown): boolean {
  const code = (error as { code?: unknown })?.code;
  return code === FIRESTORE_ALREADY_EXISTS_CODE || code === "already-exists";
}

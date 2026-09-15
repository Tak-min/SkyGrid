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
 * Never throws — logs and returns on failure, following the same discipline
 * as `buddyNotificationStore.ts`.
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
  nowMs: number;
}

/**
 * Notifies the RECIPIENT when a handle-based buddy request is received.
 * Uses `pairId` as the idempotent marker key (per ordered pair of accounts).
 */
export async function notifyRecipientOfBuddyRequest(
  db: Firestore,
  messaging: Pick<Messaging, "sendEachForMulticast">,
  params: NotifyRecipientOfBuddyRequestParams
): Promise<void> {
  const { recipientUid, pairId, requesterHandle, nowMs } = params;

  if (!(await claimNotificationMarker(db, recipientUid, pairId, "request_received", nowMs))) {
    logger.info("Buddy request received notification already claimed for this pair; skipping.", {
      recipientUid,
      pairId,
    });
    return;
  }

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
  for (const language of ["en", "ja"] as const) {
    const group = eligibleDevices.filter((device) => device.language === language);
    if (group.length === 0) continue;

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
      logger.error("Buddy request received notification send failed.", { recipientUid, language, error });
      continue;
    }

    const staleIndices = staleTokenIndices(
      response.responses.map((entry) => ({ success: entry.success, errorCode: entry.error?.code }))
    );
    for (const index of staleIndices) {
      staleRefs.push(group[index].ref);
    }
  }
  if (staleRefs.length === 0) return;

  const writer = db.bulkWriter();
  for (const ref of staleRefs) {
    writer.delete(ref);
  }
  await writer.close();
}

export interface NotifyRequesterOfBuddyApprovalParams {
  requesterUid: string;
  pairId: string;
  accepterHandle: string | null;
  nowMs: number;
}

/**
 * Notifies the REQUESTER when their pending buddy request is accepted.
 * Uses `pairId` as the idempotent marker key, keyed separately from
 * "request_received" so both notifications can fire independently.
 */
export async function notifyRequesterOfBuddyApproval(
  db: Firestore,
  messaging: Pick<Messaging, "sendEachForMulticast">,
  params: NotifyRequesterOfBuddyApprovalParams
): Promise<void> {
  const { requesterUid, pairId, accepterHandle, nowMs } = params;

  if (!(await claimNotificationMarker(db, requesterUid, pairId, "request_approved", nowMs))) {
    logger.info("Buddy request approved notification already claimed for this pair; skipping.", {
      requesterUid,
      pairId,
    });
    return;
  }

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
  for (const language of ["en", "ja"] as const) {
    const group = eligibleDevices.filter((device) => device.language === language);
    if (group.length === 0) continue;

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
      logger.error("Buddy request approved notification send failed.", { requesterUid, language, error });
      continue;
    }

    const staleIndices = staleTokenIndices(
      response.responses.map((entry) => ({ success: entry.success, errorCode: entry.error?.code }))
    );
    for (const index of staleIndices) {
      staleRefs.push(group[index].ref);
    }
  }
  if (staleRefs.length === 0) return;

  const writer = db.bulkWriter();
  for (const ref of staleRefs) {
    writer.delete(ref);
  }
  await writer.close();
}

/** `false` means a marker already existed — the caller must not send anything. */
async function claimNotificationMarker(
  db: Firestore,
  uid: string,
  pairId: string,
  notificationType: "request_received" | "request_approved",
  nowMs: number
): Promise<boolean> {
  const markerRef = db
    .collection(USERS)
    .doc(uid)
    .collection(BUDDY_REQUEST_NOTIFICATION_MARKERS)
    .doc(`${pairId}_${notificationType}`);
  try {
    await markerRef.create({
      createdAt: FieldValue.serverTimestamp(),
      expireAt: Timestamp.fromMillis(nowMs + BUDDY_REQUEST_NOTIFICATION_MARKER_RETENTION_MS),
    });
    return true;
  } catch (error: unknown) {
    if (isAlreadyExistsError(error)) return false;
    logger.error("Could not claim the buddy request notification marker.", { uid, pairId, notificationType, error });
    return false;
  }
}

function isAlreadyExistsError(error: unknown): boolean {
  const code = (error as { code?: unknown })?.code;
  return code === FIRESTORE_ALREADY_EXISTS_CODE || code === "already-exists";
}

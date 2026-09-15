import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import type { Messaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import {
  activeBuddyUIDs,
  buddyPostNotificationCopy,
  deviceLanguageFromDoc,
  isWithinQuietHours,
  posterHandleFromFriendship,
  postNotificationMarkerExpireAtMs,
  staleTokenIndices,
  type FriendshipRecord,
} from "./buddyNotifications.js";

/**
 * Every Firestore/FCM access the buddy-post-notification feature makes.
 *
 * `db` and `messaging` are both parameters rather than `admin.firestore()` /
 * `admin.messaging()` calls inside — the same reason as `inviteStore.ts`: it makes
 * this module runnable against the Firestore emulator with a fake `messaging` sender,
 * without Functions, Auth, or App Check. `index.ts`'s `onBuddyPostCreated` is the thin
 * trigger shell around this.
 *
 * **Never throws.** This runs from a Firestore-triggered function: the post it is
 * reacting to is already committed, and nothing about a notification failing may ever
 * be reported back as if the post itself had failed. Every failure path here logs and
 * returns rather than propagating.
 */

const USERS = "users";
const POSTS = "posts";
const FRIENDSHIPS = "friendships";
const NOTIFICATION_MARKERS = "postNotifications";
const DEVICES = "devices";

/** A recipient with many stale/duplicate device docs still gets at most this many
 * sends — the newest registrations are the ones actually worth reaching. */
const MAX_TOKENS_PER_RECIPIENT = 10;

const FIRESTORE_ALREADY_EXISTS_CODE = 6;

export interface NotifyBuddiesOfPostParams {
  posterUid: string;
  localDate: string;
  nowMs: number;
}

export async function notifyBuddiesOfPost(
  db: Firestore,
  messaging: Pick<Messaging, "sendEachForMulticast">,
  params: NotifyBuddiesOfPostParams
): Promise<void> {
  const { posterUid, localDate, nowMs } = params;

  if (!(await claimNotificationMarker(db, posterUid, localDate, nowMs))) {
    // Already sent for this exact (poster, localDate) — an Eventarc retry, or a
    // delete-then-recapture through OrphanedPostRecovery. Costing at most one
    // notification per real post matters more than never missing a retry: a missed
    // send here is not the recipient's only chance to find out, since their own
    // foreground return re-resolves the buddy strip anyway
    // (`TodayViewModel.refreshBuddiesNow`).
    logger.info("Buddy post notification already claimed for this post; skipping.", {
      posterUid,
      localDate,
    });
    return;
  }

  let friendshipDocs;
  try {
    const snapshot = await db.collection(FRIENDSHIPS).where("members", "array-contains", posterUid).get();
    friendshipDocs = snapshot.docs;
  } catch (error: unknown) {
    logger.error("Could not read friendships for a buddy post notification.", { posterUid, error });
    return;
  }

  const friendships = friendshipDocs.map((doc) => doc.data() as FriendshipRecord);
  const buddyUIDs = activeBuddyUIDs(posterUid, friendships);
  if (buddyUIDs.length === 0) return;

  await Promise.all(
    buddyUIDs.map((buddyUid) => {
      const friendshipDoc = friendshipDocs.find((doc) => (doc.data().members as string[]).includes(buddyUid));
      const posterHandle = friendshipDoc
        ? posterHandleFromFriendship(posterUid, friendshipDoc.data() as {
            requestedBy: string;
            requestedByHandle?: string | null;
            recipientHandle?: string | null;
          })
        : null;
      return notifyOneBuddy(db, messaging, { posterUid, buddyUid, localDate, nowMs, posterHandle });
    })
  );
}

/** `false` means a marker already existed — the caller must not send anything. */
async function claimNotificationMarker(
  db: Firestore,
  posterUid: string,
  localDate: string,
  nowMs: number
): Promise<boolean> {
  const markerRef = db.collection(USERS).doc(posterUid).collection(NOTIFICATION_MARKERS).doc(localDate);
  try {
    await markerRef.create({
      createdAt: FieldValue.serverTimestamp(),
      expireAt: Timestamp.fromMillis(postNotificationMarkerExpireAtMs(nowMs)),
    });
    return true;
  } catch (error: unknown) {
    if (isAlreadyExistsError(error)) return false;
    // An unexpected write failure (permissions, transient outage) must not be
    // mistaken for "already sent" — that would silently and permanently suppress a
    // real notification. Log and treat as "could not claim, do not send this time";
    // the marker was never created, so a later retry can still claim it.
    logger.error("Could not claim the buddy post notification marker.", { posterUid, localDate, error });
    return false;
  }
}

async function notifyOneBuddy(
  db: Firestore,
  messaging: Pick<Messaging, "sendEachForMulticast">,
  params: {
    posterUid: string;
    buddyUid: string;
    localDate: string;
    nowMs: number;
    posterHandle: string | null;
  }
): Promise<void> {
  const { posterUid, buddyUid, localDate, nowMs, posterHandle } = params;

  const [recipientDoc, recipientPostDoc, devicesSnapshot] = await Promise.all([
    db.collection(USERS).doc(buddyUid).get(),
    db.collection(USERS).doc(buddyUid).collection(POSTS).doc(localDate).get(),
    db
      .collection(USERS)
      .doc(buddyUid)
      .collection(DEVICES)
      .orderBy("updatedAt", "desc")
      .limit(MAX_TOKENS_PER_RECIPIENT)
      .get(),
  ]);

  // The recipient account was deleted between the friendship read and here.
  if (!recipientDoc.exists) return;

  const timezone = recipientDoc.data()?.timezone;
  if (typeof timezone === "string" && isWithinQuietHours(timezone, nowMs)) return;

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
  // Different devices can record different in-app languages, so a single multicast
  // with one title/body is not correct — group by language and send once per group.
  for (const language of ["en", "ja"] as const) {
    const group = eligibleDevices.filter((device) => device.language === language);
    if (group.length === 0) continue;

    const copy = buddyPostNotificationCopy({
      posterHandle,
      recipientHasPostedToday: recipientPostDoc.exists,
      language,
    });

    let response;
    try {
      response = await messaging.sendEachForMulticast({
        tokens: group.map((device) => device.token),
        notification: { title: copy.title, body: copy.body },
        data: { type: "buddy_post", posterUid, localDate },
        apns: {
          headers: { "apns-collapse-id": collapseId(posterUid, localDate) },
          payload: { aps: { sound: "default", "thread-id": "buddy-post" } },
        },
      });
    } catch (error: unknown) {
      // FCM outage or a malformed payload — the post is already committed and nothing
      // here can undo it. Log and move on; this buddy simply misses this one nudge.
      logger.error("Buddy post notification send failed.", { buddyUid, language, error });
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

/** `apns-collapse-id` is capped at 64 bytes by APNs; UID + date length never gets
 * close, but the cap is enforced defensively rather than assumed. */
function collapseId(posterUid: string, localDate: string): string {
  return `bp_${posterUid}_${localDate}`.slice(0, 64);
}

function isAlreadyExistsError(error: unknown): boolean {
  const code = (error as { code?: unknown })?.code;
  return code === FIRESTORE_ALREADY_EXISTS_CODE || code === "already-exists";
}

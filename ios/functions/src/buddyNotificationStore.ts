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
 * Transient FCM send failures are thrown only after the send lease is released, so
 * Eventarc can retry without replaying recipients already finalized as `sent`.
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

/**
 * Claims a recipient-*and-language*-scoped marker. The old implementation
 * claimed one marker per recipient before knowing which language groups had
 * eligible devices: a send failure in one language marked the whole recipient
 * "sent" the instant any other language succeeded, silently and permanently
 * dropping the failed language's notification (see `notifyOneBuddy`). Scoping
 * the marker to `${posterUid}_${localDate}_${language}` makes each language's
 * delivery and retry fully independent, and also fixes the original problem
 * this comment used to describe: a new buddy added after the first fan-out can
 * still receive that day's post, since each recipient/language pair is judged
 * on its own.
 *
 * A short lease gives concurrent Eventarc deliveries one sender while allowing a
 * crashed/failed delivery to be retried. The marker is promoted to `sent` only
 * after FCM reports at least one successful delivery, or after a permanent
 * (non-retryable) FCM error — see `isPermanentFcmError` and `finishNotificationMarker`.
 */
async function claimNotificationMarker(
  db: Firestore,
  recipientUid: string,
  posterUid: string,
  localDate: string,
  language: string,
  nowMs: number
): Promise<boolean> {
  const markerRef = db.collection(USERS).doc(recipientUid).collection(NOTIFICATION_MARKERS).doc(`${posterUid}_${localDate}_${language}`);
  const leaseUntil = Timestamp.fromMillis(nowMs + 5 * 60 * 1000);
  try {
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(markerRef);
      const data = existing.data();
      if (existing.exists && data?.state === "sent") {
        throw new Error("already-sent");
      }
      const activeLease = data?.state === "sending"
        && data.leaseUntil instanceof Timestamp
        && data.leaseUntil.toMillis() > nowMs;
      if (activeLease) throw new Error("already-sending");
      const payload = {
        createdAt: data?.createdAt ?? FieldValue.serverTimestamp(),
        expireAt: Timestamp.fromMillis(postNotificationMarkerExpireAtMs(nowMs)),
        state: "sending",
        leaseUntil,
      };
      if (existing.exists) transaction.update(markerRef, payload);
      else transaction.create(markerRef, payload);
    });
    return true;
  } catch (error: unknown) {
    if (error instanceof Error && (error.message === "already-sent" || error.message === "already-sending")) return false;
    if (isAlreadyExistsError(error)) return false;
    // An unexpected write failure (permissions, transient outage) must not be
    // mistaken for "already sent" — that would silently and permanently suppress a
    // real notification. Log and treat as "could not claim, do not send this time";
    // the marker was never created, so a later retry can still claim it.
    logger.error("Could not claim the buddy post notification marker.", { posterUid, localDate, language, error });
    return false;
  }
}

/**
 * `sent: true` means "never attempt this recipient/language/date again" — either
 * it was actually delivered, or it failed with a permanent (non-retryable) FCM
 * error (see `isPermanentFcmError`). `sent: false` deletes the marker so a
 * genuinely transient failure can be claimed again by the next delivery.
 */
async function finishNotificationMarker(
  db: Firestore,
  recipientUid: string,
  posterUid: string,
  localDate: string,
  language: string,
  sent: boolean,
): Promise<void> {
  const markerRef = db.collection(USERS).doc(recipientUid).collection(NOTIFICATION_MARKERS).doc(`${posterUid}_${localDate}_${language}`);
  try {
    if (sent) {
      await markerRef.update({ state: "sent", leaseUntil: null });
    } else {
      await markerRef.delete();
    }
  } catch (error: unknown) {
    logger.error("Could not finalize the buddy post notification marker.", {
      recipientUid,
      posterUid,
      localDate,
      language,
      sent,
      error,
    });
  }
}

/**
 * `sendEachForMulticast` can throw at the top level — distinct from a per-token
 * failure in `response.responses[i].error`, which `staleTokenIndices` already
 * handles. A request-shape or credential error fails identically on every
 * retry: rethrowing it would have Eventarc hammer the same failure for its
 * entire retry window (up to 24h), re-reading friendships/devices every attempt
 * for no benefit. Everything else (rate limits, transient outages, unrecognized
 * codes, bare network errors) is treated as retryable, which is the safer
 * default when in doubt.
 */
const PERMANENT_FCM_ERROR_CODES = new Set([
  "messaging/invalid-argument",
  "messaging/invalid-recipient",
  "messaging/mismatched-credential",
  "messaging/sender-id-mismatch",
  "messaging/third-party-auth-error",
  "messaging/authentication-error",
]);

function isPermanentFcmError(error: unknown): boolean {
  const code = (error as { code?: unknown })?.code;
  return typeof code === "string" && PERMANENT_FCM_ERROR_CODES.has(code);
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

  // No marker claim here — moved into the per-language loop below, now that
  // each language claims and finalizes independently. Reads are cheap and
  // idempotent, so concurrent Eventarc deliveries doing them twice is fine;
  // only the actual send needs the transactional gate.
  let recipientDoc: FirebaseFirestore.DocumentSnapshot;
  let recipientPostDoc: FirebaseFirestore.DocumentSnapshot;
  let devicesSnapshot: FirebaseFirestore.QuerySnapshot;
  try {
    [recipientDoc, recipientPostDoc, devicesSnapshot] = await Promise.all([
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
  } catch (error: unknown) {
    logger.error("Could not read recipient data for a buddy post notification.", { buddyUid, posterUid, localDate, error });
    return;
  }

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
  let anyRetryableFailure = false;
  // Different devices can record different in-app languages, so a single multicast
  // with one title/body is not correct — group by language and send once per group.
  // Each language claims, sends, and finalizes its own marker (see
  // `claimNotificationMarker`), so one language's failure can never block or
  // falsely complete another.
  for (const language of ["en", "ja"] as const) {
    const group = eligibleDevices.filter((device) => device.language === language);
    if (group.length === 0) continue;

    if (!(await claimNotificationMarker(db, buddyUid, posterUid, localDate, language, nowMs))) {
      logger.info("Buddy post notification already claimed for this recipient, post, and language; skipping.", {
        buddyUid,
        posterUid,
        localDate,
        language,
      });
      continue;
    }

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
      const permanent = isPermanentFcmError(error);
      logger.error("Buddy post notification send failed.", { buddyUid, language, permanent, error });
      // Permanent: mark this language handled so it is never retried — retrying
      // an invalid-argument/credential error forever would only burn quota.
      // Transient: release the marker so the next delivery can claim it again.
      await finishNotificationMarker(db, buddyUid, posterUid, localDate, language, permanent);
      if (!permanent) anyRetryableFailure = true;
      continue;
    }

    const staleIndices = staleTokenIndices(
      response.responses.map((entry) => ({ success: entry.success, errorCode: entry.error?.code }))
    );
    const delivered = response.successCount > 0;
    await finishNotificationMarker(db, buddyUid, posterUid, localDate, language, delivered);
    // `sendEachForMulticast` can resolve even when every token failed. Stale
    // registrations are terminal and are deleted below; any other failed token
    // is retryable, so release the lease and ask Eventarc to redeliver.
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
    throw new Error(`Buddy post notification had a retryable send failure for recipient ${buddyUid} (poster ${posterUid}, ${localDate}).`);
  }
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

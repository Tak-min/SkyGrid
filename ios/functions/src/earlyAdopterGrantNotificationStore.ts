import type { Firestore } from "firebase-admin/firestore";
import type { Messaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { deviceLanguageFromDoc, staleTokenIndices } from "./buddyNotifications.js";
import {
  earlyAdopterGrantNotificationCopy,
  type DeviceLanguage,
} from "./earlyAdopterGrantNotifications.js";

/**
 * Every Firestore/FCM access the early-adopter-grant-notification feature makes.
 *
 * `db` and `messaging` are both parameters rather than `admin.firestore()` /
 * `admin.messaging()` calls inside — the same reason as `buddyNotificationStore.ts`:
 * it makes this module runnable against the Firestore emulator with a fake
 * `messaging` sender, without Functions, Auth, or App Check. `index.ts`'s
 * `onEarlyAdopterGrantCompleted` is the thin trigger shell around this.
 *
 * **Never throws.** This runs from a Firestore-triggered function: the grant
 * it is reacting to is already committed, and nothing about a notification
 * failing may ever be reported back as if the grant itself had failed. Every
 * failure path here logs and returns rather than propagating.
 */

const USERS = "users";
const DEVICES = "devices";

/** A recipient with many stale/duplicate device docs still gets at most this many
 * sends — the newest registrations are the ones actually worth reaching. */
const MAX_TOKENS_PER_RECIPIENT = 10;

export interface NotifyEarlyAdopterGrantCompletedParams {
  uid: string;
}

export async function notifyEarlyAdopterGrantCompleted(
  db: Firestore,
  messaging: Pick<Messaging, "sendEachForMulticast">,
  params: NotifyEarlyAdopterGrantCompletedParams
): Promise<void> {
  const { uid } = params;

  let devicesSnapshot;
  try {
    devicesSnapshot = await db
      .collection(USERS)
      .doc(uid)
      .collection(DEVICES)
      .orderBy("updatedAt", "desc")
      .limit(MAX_TOKENS_PER_RECIPIENT)
      .get();
  } catch (error: unknown) {
    logger.error("Could not read devices for an early adopter grant notification.", {
      uid,
      error,
    });
    return;
  }

  type EligibleDevice = {
    ref: FirebaseFirestore.DocumentReference;
    token: string;
    language: ReturnType<typeof deviceLanguageFromDoc>;
  };
  const eligibleDevices: EligibleDevice[] = devicesSnapshot.docs
    .map((doc) => {
      const token = doc.data().fcmToken as string | undefined;
      if (!token) return null;
      return {
        ref: doc.ref,
        token,
        language: deviceLanguageFromDoc(doc.data().language),
      };
    })
    .filter((entry): entry is EligibleDevice => entry !== null);
  if (eligibleDevices.length === 0) return;

  const staleRefs: FirebaseFirestore.DocumentReference[] = [];
  // Different devices can record different in-app languages, so group by language
  // and send once per group.
  for (const language of ["en", "ja"] as const) {
    const group = eligibleDevices.filter((device) => device.language === language);
    if (group.length === 0) continue;

    const copy = earlyAdopterGrantNotificationCopy({ language });

    let response;
    try {
      response = await messaging.sendEachForMulticast({
        tokens: group.map((device) => device.token),
        notification: { title: copy.title, body: copy.body },
        data: { type: "early_adopter_grant", uid },
        apns: {
          headers: { "apns-collapse-id": `eag_${uid}`.slice(0, 64) },
          payload: { aps: { sound: "default", "thread-id": "early-adopter-grant" } },
        },
      });
    } catch (error: unknown) {
      // FCM outage or a malformed payload — the grant is already committed and
      // nothing here can undo it. Log and move on; this user simply misses this
      // one notification.
      logger.error("Early adopter grant notification send failed.", { uid, language, error });
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

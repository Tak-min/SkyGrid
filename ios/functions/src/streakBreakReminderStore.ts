import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import type { Messaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import {
  isWithinQuietHours,
  localHourForTimezone,
  localDateStringForTimezone,
  previousDayString,
  streakBreakNotificationCopy,
  personalStreakBreakNotificationCopy,
  streakBreakNotificationMarkerExpireAtMs,
  deviceLanguageFromDoc,
  type FriendshipRecord,
} from "./streakBreakReminders.js";
import { staleTokenIndices } from "./buddyNotifications.js";

/**
 * Every Firestore/FCM access the streak-break-reminder feature makes.
 *
 * `db` and `messaging` are both parameters rather than `admin.firestore()` /
 * `admin.messaging()` calls inside — the same reason as `inviteStore.ts`: it makes
 * this module runnable against the Firestore emulator with a fake `messaging` sender,
 * without Functions, Auth, or App Check. `index.ts`'s `onStreakBreakReminder` is the
 * thin trigger shell around this.
 *
 * Transient FCM failures are rethrown after their lease marker is released so the
 * scheduler's bounded retry policy can try again without duplicating sent reminders.
 */

const USERS = "users";
const FRIENDSHIPS = "friendships";
const POSTS = "posts";
const STREAK_BREAK_NOTIFICATION_MARKERS = "streakBreakNotifications";
const DEVICES = "devices";

/** A recipient with many stale/duplicate device docs still gets at most this many
 * sends — the newest registrations are the ones actually worth reaching. */
const MAX_TOKENS_PER_RECIPIENT = 10;

const FIRESTORE_ALREADY_EXISTS_CODE = 6;

export interface NotifyStreakBreakReminderParams {
  nowMs: number;
}

export async function notifyStreakBreakReminders(
  db: Firestore,
  messaging: Pick<Messaging, "sendEachForMulticast">,
  params: NotifyStreakBreakReminderParams
): Promise<void> {
  const { nowMs } = params;

  let friendshipDocs;
  try {
    // Find all accepted friendships with an active streak where the last mutual
    // date was yesterday (no posts yet today, streak about to break).
    const snapshot = await db
      .collection(FRIENDSHIPS)
      .where("status", "==", "accepted")
      .where("streakCurrent", ">=", 1)
      .get();
    friendshipDocs = snapshot.docs;
  } catch (error: unknown) {
    logger.error("Could not read friendships for streak break reminders.", { error });
    return;
  }

  if (friendshipDocs.length === 0) return;

  // For each pair, check if the streak is about to break today.
  // We need each recipient's timezone to determine what "today" means for them.
  const notifications = friendshipDocs
    .map((doc) => {
      const data = doc.data() as FriendshipRecord;
      if (
        data.streakCurrent < 1
        || !Array.isArray(data.members)
        || data.members.length !== 2
        || !Array.isArray(data.blockedBy)
        || data.blockedBy.length !== 0
        || typeof data.streakLastMutualDate !== "string"
      ) {
        return null;
      }
      return { pairId: doc.id, data };
    })
    .filter((entry) => entry !== null);

  if (notifications.length === 0) return;

  // Process each pair: notify both members if their streak is at risk.
  await Promise.all(
    notifications.map(async (entry) => {
      if (!entry) return;
      const { pairId, data } = entry;
      const members = data.members as string[];
      const streakCurrent = data.streakCurrent;
      const lastMutualDate = data.streakLastMutualDate;

      // Both members are the same pair, so we notify both.
      await Promise.all(
        members.map((memberId) =>
          notifyOneStreakBreakReminder(db, messaging, {
            memberId,
            pairId,
            streakCurrent,
            lastMutualDate,
            nowMs,
          })
        )
      );
    })
  );
}

/** Sends the same evening nudge for each user's own daily posting streak. The
 * server-owned profile streak is updated by `updatePersonalStreakForPost`, so this
 * remains reliable even when the app has not been opened today. */
export async function notifyPersonalStreakBreakReminders(
  db: Firestore,
  messaging: Pick<Messaging, "sendEachForMulticast">,
  params: NotifyStreakBreakReminderParams,
): Promise<void> {
  let usersSnapshot: FirebaseFirestore.QuerySnapshot;
  try {
    // Unfiltered before: a full collection scan every hour, forever, regardless
    // of how many users have no active streak at all. Mirrors the same
    // `streakCurrent >= 1` filter `notifyStreakBreakReminders` already applies
    // to `friendships`.
    usersSnapshot = await db.collection(USERS).where("streakCurrent", ">=", 1).get();
  } catch (error: unknown) {
    logger.error("Could not read users for personal streak break reminders.", { error });
    return;
  }

  await Promise.all(usersSnapshot.docs.map(async (user) => {
    const data = user.data();
    const streakCurrent = typeof data.streakCurrent === "number" ? data.streakCurrent : 0;
    const lastPostLocalDate = typeof data.lastPostLocalDate === "string" ? data.lastPostLocalDate : null;
    const timezone = typeof data.timezone === "string" ? data.timezone : null;
    if (streakCurrent < 1 || !lastPostLocalDate || !timezone) return;

    // The scheduler runs hourly worldwide. Only the recipient's 20:00 hour is an
    // eligible send window; without this gate the first non-quiet run could alert
    // at 05:00. Invalid timezones fail closed.
    if (localHourForTimezone(params.nowMs, timezone) !== 20) return;
    const localToday = localDateStringForTimezone(params.nowMs, timezone);
    if (lastPostLocalDate !== previousDayString(localToday) || isWithinQuietHours(timezone, params.nowMs)) return;

    if (!(await claimDailyReminderMarker(db, user.id, localToday, params.nowMs))) return;

    let devicesSnapshot: FirebaseFirestore.QuerySnapshot;
    try {
      devicesSnapshot = await db.collection(USERS).doc(user.id).collection(DEVICES)
        .orderBy("updatedAt", "desc").limit(MAX_TOKENS_PER_RECIPIENT).get();
    } catch (error: unknown) {
      await finishDailyReminderMarker(db, user.id, localToday, false);
      logger.error("Could not read devices for personal streak break reminder.", { uid: user.id, error });
      return;
    }

    type EligibleDevice = { ref: FirebaseFirestore.DocumentReference; token: string; language: ReturnType<typeof deviceLanguageFromDoc> };
    const devices: EligibleDevice[] = devicesSnapshot.docs.map((doc) => {
      const token = doc.data().fcmToken as string | undefined;
      return token ? { ref: doc.ref, token, language: deviceLanguageFromDoc(doc.data().language) } : null;
    }).filter((device): device is EligibleDevice => device !== null);
    if (devices.length === 0) {
      await finishDailyReminderMarker(db, user.id, localToday, false);
      return;
    }

    const staleRefs: FirebaseFirestore.DocumentReference[] = [];
    let delivered = false;
    let sendFailure: unknown;
    for (const language of ["en", "ja"] as const) {
      const group = devices.filter((device) => device.language === language);
      if (group.length === 0) continue;
      const copy = personalStreakBreakNotificationCopy({ currentStreak: streakCurrent, language });
      try {
        const response = await messaging.sendEachForMulticast({
          tokens: group.map((device) => device.token),
          notification: { title: copy.title, body: copy.body },
          data: { type: "personal_streak_break_reminder", localDate: localToday },
          apns: {
            headers: { "apns-collapse-id": `psr_${localToday}`.slice(0, 64) },
            payload: { aps: { sound: "default", "thread-id": "streak-reminder" } },
          },
        });
        delivered ||= response.successCount > 0;
        const staleIndices = staleTokenIndices(response.responses.map((entry) => ({
          success: entry.success,
          errorCode: entry.error?.code,
        })));
        for (const index of staleIndices) staleRefs.push(group[index].ref);
        if (response.successCount === 0 && staleIndices.length < response.responses.length) {
          sendFailure = new Error(`Personal streak reminder had retryable token failures for ${user.id}.`);
        }
      } catch (error: unknown) {
        logger.error("Personal streak break reminder send failed.", { uid: user.id, language, error });
        sendFailure = error;
      }
    }

    if (staleRefs.length > 0) {
      const writer = db.bulkWriter();
      staleRefs.forEach((ref) => writer.delete(ref));
      await writer.close();
    }
    await finishDailyReminderMarker(db, user.id, localToday, delivered);
    if (!delivered && sendFailure) throw sendFailure;
  }));
}

/**
 * Shared by both the personal and mutual streak reminders: one marker per
 * user per day (`daily_{localDate}`), not two independent ones. Two
 * consequences fall out of that:
 *
 * 1. Whichever half runs first for a given user this hour (mutual, since
 *    `index.ts`'s `onStreakBreakReminder` awaits it first) claims the day's
 *    single marker; the other half's later claim fails and it skips — so a
 *    user whose personal *and* mutual streaks are both at risk on the same
 *    day gets exactly one reminder, not two.
 * 2. The old per-purpose markers (`mutual_{date}`/`personal_{date}`) were
 *    claimed with a bare `create()` and no lease: a crash between claim and
 *    finish left a marker with no `state` field, which `already-exists`
 *    then blocked forever — the notification was lost for that day with no
 *    way to retry. This transaction + short lease mirrors
 *    `buddyNotificationStore.ts`'s `claimNotificationMarker`: a failed send
 *    releases the marker (delete) so the next delivery can claim it again,
 *    while a lease still in force blocks a concurrent duplicate send.
 */
async function claimDailyReminderMarker(db: Firestore, uid: string, localDate: string, nowMs: number): Promise<boolean> {
  const markerRef = db.collection(USERS).doc(uid).collection(STREAK_BREAK_NOTIFICATION_MARKERS).doc(`daily_${localDate}`);
  const leaseUntil = Timestamp.fromMillis(nowMs + 5 * 60 * 1000);
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
        expireAt: Timestamp.fromMillis(streakBreakNotificationMarkerExpireAtMs(nowMs)),
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
    logger.error("Could not claim the daily streak reminder marker.", { uid, localDate, error });
    return false;
  }
}

async function finishDailyReminderMarker(db: Firestore, uid: string, localDate: string, sent: boolean): Promise<void> {
  const markerRef = db.collection(USERS).doc(uid).collection(STREAK_BREAK_NOTIFICATION_MARKERS).doc(`daily_${localDate}`);
  try {
    if (sent) await markerRef.update({ state: "sent", leaseUntil: null });
    else await markerRef.delete();
  } catch (error: unknown) {
    logger.error("Could not finalize the daily streak reminder marker.", { uid, localDate, sent, error });
  }
}

async function notifyOneStreakBreakReminder(
  db: Firestore,
  messaging: Pick<Messaging, "sendEachForMulticast">,
  params: {
    memberId: string;
    pairId: string;
    streakCurrent: number;
    lastMutualDate: string;
    nowMs: number;
  }
): Promise<void> {
  const { memberId, pairId, streakCurrent, lastMutualDate, nowMs } = params;

  // Fetch recipient's user doc for timezone.
  let recipientDoc;
  try {
    recipientDoc = await db.collection(USERS).doc(memberId).get();
  } catch (error: unknown) {
    logger.error("Could not read user for streak break reminder.", { memberId, error });
    return;
  }

  if (!recipientDoc.exists) return;

  const recipientData = recipientDoc.data();
  const timezone = recipientData?.timezone;
  if (!timezone || typeof timezone !== "string") return;

  if (localHourForTimezone(nowMs, timezone) !== 20) return;

  // Determine what "today" is in the recipient's timezone.
  const localToday = localDateStringForTimezone(nowMs, timezone);
  const expectedYesterdayString = previousDayString(localToday);

  // Only send if the streak's last mutual date was yesterday.
  if (lastMutualDate !== expectedYesterdayString) {
    return;
  }

  // A member who already posted today has no at-risk mutual streak. This check
  // must be per recipient: one buddy may have posted while the other has not.
  try {
    const ownPost = await db.collection(USERS).doc(memberId).collection(POSTS).doc(localToday).get();
    if (ownPost.exists) return;
  } catch (error: unknown) {
    logger.error("Could not read today's post for a streak break reminder.", { memberId, error });
    return;
  }

  // Check quiet hours.
  if (isWithinQuietHours(timezone, nowMs)) {
    return;
  }

  // Claim one mutual-reminder slot per member/date, preventing a separate push for
  // every at-risk buddy pair.
  if (!(await claimDailyReminderMarker(db, memberId, localToday, nowMs))) {
    // Already sent today for this member — skip.
    logger.info("Streak break reminder already claimed for this member and date; skipping.", {
      memberId,
      localToday,
    });
    return;
  }

  // Fetch device tokens.
  let devicesSnapshot;
  try {
    devicesSnapshot = await db
      .collection(USERS)
      .doc(memberId)
      .collection(DEVICES)
      .orderBy("updatedAt", "desc")
      .limit(MAX_TOKENS_PER_RECIPIENT)
      .get();
  } catch (error: unknown) {
    await finishDailyReminderMarker(db, memberId, localToday, false);
    logger.error("Could not read devices for streak break reminder.", { memberId, error });
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
      return { ref: doc.ref, token, language: deviceLanguageFromDoc(doc.data().language) };
    })
    .filter((entry): entry is EligibleDevice => entry !== null);

  if (eligibleDevices.length === 0) {
    await finishDailyReminderMarker(db, memberId, localToday, false);
    return;
  }

  const staleRefs: FirebaseFirestore.DocumentReference[] = [];
  let delivered = false;
  let sendFailure: unknown;

  // Group devices by language and send once per group.
  for (const language of ["en", "ja"] as const) {
    const group = eligibleDevices.filter((device) => device.language === language);
    if (group.length === 0) continue;

    const copy = streakBreakNotificationCopy({
      currentStreak: streakCurrent,
      language,
    });

    let response;
    try {
      response = await messaging.sendEachForMulticast({
        tokens: group.map((device) => device.token),
        notification: { title: copy.title, body: copy.body },
        data: { type: "streak_break_reminder", pairId },
        apns: {
          headers: { "apns-collapse-id": collapseId(pairId, localToday) },
          payload: { aps: { sound: "default", "thread-id": "streak-reminder" } },
        },
      });
    } catch (error: unknown) {
      logger.error("Streak break reminder send failed.", { memberId, pairId, language, error });
      sendFailure = error;
      continue;
    }

    const staleIndices = staleTokenIndices(
      response.responses.map((entry) => ({ success: entry.success, errorCode: entry.error?.code }))
    );
    delivered ||= response.successCount > 0;
    for (const index of staleIndices) {
      staleRefs.push(group[index].ref);
    }
    if (response.successCount === 0 && staleIndices.length < response.responses.length) {
      sendFailure = new Error(`Mutual streak reminder had retryable token failures for ${memberId}.`);
    }
  }

  if (staleRefs.length > 0) {
    const writer = db.bulkWriter();
    for (const ref of staleRefs) {
      writer.delete(ref);
    }
    await writer.close();
  }
  await finishDailyReminderMarker(db, memberId, localToday, delivered);
  if (!delivered && sendFailure) throw sendFailure;
}

/** `apns-collapse-id` is capped at 64 bytes by APNs. */
function collapseId(pairId: string, localDate: string): string {
  return `sbr_${pairId}_${localDate}`.slice(0, 64);
}

function isAlreadyExistsError(error: unknown): boolean {
  const code = (error as { code?: unknown })?.code;
  return code === FIRESTORE_ALREADY_EXISTS_CODE || code === "already-exists";
}

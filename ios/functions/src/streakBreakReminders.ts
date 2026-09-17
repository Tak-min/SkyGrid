/**
 * Pure decision logic for streak-break-reminder push notifications: which buddy pairs
 * are at risk of losing their streak today, what the notification says, and whether
 * it would land in someone's quiet hours.
 *
 * Kept free of `firebase-admin` for testability: timezone or off-by-one mistakes here
 * are exactly the kind of thing that is trivial to get wrong and impossible to see in
 * an emulator run. `streakBreakReminderStore.ts` is the thin Firestore/FCM-aware shell
 * that wires this to real data.
 */

export interface FriendshipRecord {
  members: string[];
  status: "pending" | "accepted";
  blockedBy: string[];
  streakCurrent: number;
  streakLastMutualDate: string; // "YYYY-MM-DD" format
}

export interface StreakBreakNotificationCopy {
  title: string;
  body: string;
}

/** The two in-app languages Sky Grid supports server-side. Unknown/missing device
 * language data always falls back to English — never assume Japanese. */
export type DeviceLanguage = "en" | "ja";

/** Reads a Firestore device-doc `language` field defensively. Anything other than
 * the literal string `"ja"` (including `undefined`, `null`, or a stale/garbage
 * value) resolves to `"en"`. */
export function deviceLanguageFromDoc(value: unknown): DeviceLanguage {
  return value === "ja" ? "ja" : "en";
}

/**
 * House voice: short, declarative, no exclamation points. Streak is the core
 * retention mechanic, so this copy emphasizes the mutual aspect ("together").
 * Japanese keeps the same understated, declarative register — casual sentence-final
 * particles (よ/ね/だ), not exclamation-heavy.
 */
export function streakBreakNotificationCopy(params: {
  currentStreak: number;
  language: DeviceLanguage;
}): StreakBreakNotificationCopy {
  const { currentStreak, language } = params;
  if (language === "ja") {
    return {
      title: `今日投稿しないと${currentStreak}日のストリークが途切れるよ。`,
      body: "一緒に空を撮ってストリークを守ろう。",
    };
  }
  return {
    title: `Your ${currentStreak}-day streak ends today without a post.`,
    body: "Capture the sky together to keep it alive.",
  };
}

/** Copy for the user's own daily streak. Keep it separate from the mutual copy:
 * mentioning "together" when only the user's post is missing is misleading. */
export function personalStreakBreakNotificationCopy(params: {
  currentStreak: number;
  language: DeviceLanguage;
}): StreakBreakNotificationCopy {
  if (params.language === "ja") {
    return {
      title: `${params.currentStreak}日のストリークを今日もつなごう。`,
      body: "空を撮って、今日の記録をつなごう。",
    };
  }
  return {
    title: `Keep your ${params.currentStreak}-day streak safe today.`,
    body: "Capture today's sky to keep your record going.",
  };
}

/**
 * Converts a local date string ("YYYY-MM-DD") to the previous calendar day in the same format.
 * Used to check if a streak was last updated yesterday.
 */
export function previousDayString(dateStr: string): string {
  const date = new Date(dateStr + "T00:00:00Z");
  date.setUTCDate(date.getUTCDate() - 1);
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  const day = String(date.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * Converts an ISO timestamp (milliseconds since epoch) to a local date string in the given timezone.
 * Returns "YYYY-MM-DD" format.
 */
export function localDateStringForTimezone(nowMs: number, timezone: string): string {
  try {
    const formatter = new Intl.DateTimeFormat("en-CA", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
    return formatter.format(new Date(nowMs));
  } catch {
    // Fallback to UTC if timezone is invalid.
    const date = new Date(nowMs);
    const year = date.getUTCFullYear();
    const month = String(date.getUTCMonth() + 1).padStart(2, "0");
    const day = String(date.getUTCDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }
}

/** Returns the recipient's local 24-hour clock hour, or `null` for an invalid
 * timezone. Scheduled reminder callers must fail closed: silently treating an
 * invalid profile timezone as UTC can send an evening reminder before dawn. */
export function localHourForTimezone(nowMs: number, timezone: string): number | null {
  try {
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      hour: "numeric",
      hourCycle: "h23",
    });
    const hour = Number(formatter.format(new Date(nowMs)));
    return Number.isInteger(hour) && hour >= 0 && hour <= 23 ? hour : null;
  } catch {
    return null;
  }
}

const QUIET_HOURS_START_HOUR = 22; // 22:00 local, inclusive
const QUIET_HOURS_END_HOUR = 5; // 05:00 local, exclusive

/**
 * `true` only when the recipient's local clock genuinely falls in the quiet window.
 * An unparseable/unsupported `timezone` returns `true` (do not send). Sending at an
 * unknown local hour is more harmful than waiting until the profile is repaired.
 *
 * For scheduled functions (unlike event-triggered ones), we don't have the recipient's
 * device doc immediately available here. The caller (streakBreakReminderStore) will
 * check this for each recipient after fetching their device/user doc.
 */
export function isWithinQuietHours(timezone: string, nowMs: number): boolean {
  const hour = localHourForTimezone(nowMs, timezone);
  if (hour === null) return true;
  return hour >= QUIET_HOURS_START_HOUR || hour < QUIET_HOURS_END_HOUR;
}

/**
 * Marker retention for streak-break-reminder notifications: approximately one week,
 * matching the same pattern as postNotificationMarkerExpireAtMs in buddyNotifications.ts.
 */
const STREAK_BREAK_NOTIFICATION_MARKER_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;

export function streakBreakNotificationMarkerExpireAtMs(nowMs: number): number {
  return nowMs + STREAK_BREAK_NOTIFICATION_MARKER_RETENTION_MS;
}

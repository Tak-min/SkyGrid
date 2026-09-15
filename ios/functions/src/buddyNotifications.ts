/**
 * Pure decision logic for buddy-post push notifications: which accepted buddies get
 * notified, what the notification says, whether it would land in someone's quiet
 * hours, and which FCM send failures mean a device token is permanently dead.
 *
 * Kept free of `firebase-admin` for the same reason as `rateLimit.ts` /
 * `subscriptionState.ts` / `invites.ts`: a timezone or off-by-one mistake here is
 * exactly the kind of thing that is trivial to get wrong and impossible to see in an
 * emulator run. `buddyNotificationStore.ts` is the thin Firestore/FCM-aware shell that
 * wires this to real data.
 */

export interface FriendshipRecord {
  members: string[];
  status: "pending" | "accepted";
  blockedBy: string[];
}

/**
 * How many of a poster's accepted buddies are ever notified for one post. Mirrors the
 * UI's own cap on the buddy strip (`BuddyRow.swift`'s `buddies.prefix(12)`) with a
 * little headroom — SkyGrid's buddy model has no real-world case anywhere near this
 * today, so this exists as a ceiling against a pathological fan-out, not a limit
 * anyone is expected to hit.
 */
export const MAX_NOTIFIED_BUDDIES = 20;

/** Every accepted, unblocked buddy of `posterUid`, derived from their friendship docs. */
export function activeBuddyUIDs(
  posterUid: string,
  friendships: readonly FriendshipRecord[]
): string[] {
  return friendships
    .filter(
      (friendship) =>
        friendship.status === "accepted" &&
        friendship.blockedBy.length === 0 &&
        friendship.members.includes(posterUid)
    )
    .map((friendship) => friendship.members.find((uid) => uid !== posterUid))
    .filter((uid): uid is string => uid !== undefined)
    .slice(0, MAX_NOTIFIED_BUDDIES);
}

export interface FriendshipHandles {
  requestedBy: string;
  requestedByHandle?: string | null;
  recipientHandle?: string | null;
}

/**
 * The poster's handle as already denormalized on the friendship doc (see
 * `firestore.rules`'s `validRequestHandles`), so notifying never needs an extra
 * profile read. `null` for an older friendship created before handle denormalization
 * existed — the caller falls back to a generic "Your buddy".
 */
export function posterHandleFromFriendship(
  posterUid: string,
  friendship: FriendshipHandles
): string | null {
  const handle =
    friendship.requestedBy === posterUid
      ? friendship.requestedByHandle
      : friendship.recipientHandle;
  return handle ?? null;
}

export interface BuddyPostNotificationCopy {
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
 * House voice: short, declarative, no exclamation points (see `StreakMilestone`
 * headline copy, `MorningFollowUpScheduler`'s "Today's sky" / "Not captured yet.").
 * Never promises a photo — a buddy's sky colour is the only thing the UI ever shows
 * for them (`BuddyTile.swift`); the copy must not read as if more were coming.
 * Japanese keeps the same understated, declarative register — casual sentence-final
 * particles (よ/だ), not the exclamation-heavy tone used elsewhere in the app.
 */
export function buddyPostNotificationCopy(params: {
  posterHandle: string | null;
  recipientHasPostedToday: boolean;
  language: DeviceLanguage;
}): BuddyPostNotificationCopy {
  const name = params.posterHandle ?? (params.language === "ja" ? "バディ" : "Your buddy");
  if (params.language === "ja") {
    return params.recipientHasPostedToday
      ? { title: "両方の空がそろったよ", body: `${name}も今朝の空を撮ったよ` }
      : { title: `${name}が空を撮ったよ`, body: "空はまだ封印中だよ" };
  }
  return params.recipientHasPostedToday
    ? { title: "Both skies are in.", body: `${name} caught this morning too.` }
    : { title: `${name} caught the sky.`, body: "Yours is still sealed." };
}

const QUIET_HOURS_START_HOUR = 22; // 22:00 local, inclusive
const QUIET_HOURS_END_HOUR = 5; // 05:00 local, exclusive

/**
 * `true` only when the recipient's local clock genuinely falls in the quiet window.
 * An unparseable/unsupported `timezone` returns `false` (send anyway) rather than
 * silently withholding the notification — a person with a malformed profile field
 * losing the app's core social-pressure mechanic entirely is worse than an occasional
 * off-hours ping. These bounds are a starting default the app owner may revise; they
 * are not derived from any product research.
 */
export function isWithinQuietHours(timezone: string, nowMs: number): boolean {
  let hour: number;
  try {
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      hour: "numeric",
      hourCycle: "h23",
    });
    hour = Number(formatter.format(new Date(nowMs)));
  } catch {
    return false;
  }
  if (!Number.isFinite(hour)) return false;
  return hour >= QUIET_HOURS_START_HOUR || hour < QUIET_HOURS_END_HOUR;
}

export interface SendResult {
  success: boolean;
  errorCode?: string;
}

/**
 * FCM error codes that mean the token itself is dead (app uninstalled, or the token
 * was rotated out from under a stale copy) rather than a transient delivery failure.
 * Only these should ever cause a `users/{uid}/devices/{tokenId}` doc to be deleted.
 */
const STALE_TOKEN_ERROR_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

/**
 * Indices into `responses` (matching `sendEachForMulticast`'s response array, which is
 * positionally aligned with the token list it was called with) whose device token is
 * permanently dead and should be deleted, not merely retried.
 */
export function staleTokenIndices(responses: readonly SendResult[]): number[] {
  const indices: number[] = [];
  responses.forEach((response, index) => {
    if (!response.success && response.errorCode && STALE_TOKEN_ERROR_CODES.has(response.errorCode)) {
      indices.push(index);
    }
  });
  return indices;
}

/**
 * Disposable, mirroring `RATE_LIMIT_RETENTION_MS`'s reasoning in `inviteStore.ts`: long
 * enough to outlive any realistic Eventarc retry window, short enough not to accumulate
 * forever. An account that is deleted removes its marker immediately regardless (via
 * `deleteAccount`'s `recursiveDelete`), so this bound only matters for an account that
 * stays alive but stops posting.
 */
const POST_NOTIFICATION_MARKER_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;

export function postNotificationMarkerExpireAtMs(nowMs: number): number {
  return nowMs + POST_NOTIFICATION_MARKER_RETENTION_MS;
}

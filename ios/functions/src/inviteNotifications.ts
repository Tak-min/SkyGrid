/** Pure decision logic for friendship-created notifications. Kept free of
 * `firebase-admin` so recipient selection and PII-free copy stay easy to test. */

import type { DeviceLanguage } from "./buddyNotifications.js";

export interface FriendshipCreatedRecord {
  members?: unknown;
  status?: unknown;
  requestedBy?: unknown;
  blockedBy?: unknown;
}

/**
 * Invite claims create an already-accepted friendship whose `requestedBy` is the
 * invite creator. Ordinary handle requests are created as `pending`, so they must
 * not notify here.
 */
export function inviterUidForCreatedFriendship(
  pairId: string,
  friendship: FriendshipCreatedRecord
): string | null {
  const { members, status, requestedBy, blockedBy } = friendship;
  if (
    status !== "accepted"
    || !Array.isArray(members)
    || members.length !== 2
    || !members.every((member) => typeof member === "string")
    || members[0] === members[1]
    || members[0] >= members[1]
    || `${members[0]}_${members[1]}` !== pairId
    || typeof requestedBy !== "string"
    || !members.includes(requestedBy)
    || !Array.isArray(blockedBy)
    || blockedBy.length !== 0
  ) {
    return null;
  }
  return requestedBy;
}

export interface InviteClaimedNotificationCopy {
  title: string;
  body: string;
}

export function inviteClaimedNotificationCopy(language: DeviceLanguage): InviteClaimedNotificationCopy {
  if (language === "ja") {
    return {
      title: "招待が使われたよ",
      body: "バディになったよ。Sky Gridを開いて挨拶しよう",
    };
  }
  return {
    title: "Your invite was claimed.",
    body: "You’re buddies now. Open Sky Grid to say hi.",
  };
}

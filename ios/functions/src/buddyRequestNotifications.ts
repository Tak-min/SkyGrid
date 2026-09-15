/**
 * Pure decision logic for buddy-request notifications: (a) when a handle-based
 * request is received, and (b) when a pending request is accepted.
 *
 * Kept free of `firebase-admin` for testability, same discipline as
 * `buddyNotifications.ts` and `inviteNotifications.ts`.
 */

import type { DeviceLanguage } from "./buddyNotifications.js";

export interface BuddyRequestReceivedNotificationCopy {
  title: string;
  body: string;
}

/**
 * Notification sent to the RECIPIENT when a handle-based buddy request is received.
 * House voice: short, declarative, no exclamation points.
 * The recipient's handle is not exposed (they already know their own handle);
 * we surface the requester's handle so they know who wants to connect.
 */
export function buddyRequestReceivedNotificationCopy(params: {
  requesterHandle: string | null;
  language: DeviceLanguage;
}): BuddyRequestReceivedNotificationCopy {
  const name = params.requesterHandle ?? (params.language === "ja" ? "誰か" : "Someone");
  if (params.language === "ja") {
    return {
      title: `${name}からバディリクエスト`,
      body: "Sky Gridを開いて確認しよう",
    };
  }
  return {
    title: `${name} wants to be buddies`,
    body: "Open Sky Grid to respond.",
  };
}

export interface BuddyRequestApprovedNotificationCopy {
  title: string;
  body: string;
}

/**
 * Notification sent to the REQUESTER when their pending request is accepted.
 * House voice: short, celebratory but restrained.
 * The accepter's handle tells the requester who said yes.
 */
export function buddyRequestApprovedNotificationCopy(params: {
  accepterHandle: string | null;
  language: DeviceLanguage;
}): BuddyRequestApprovedNotificationCopy {
  const name = params.accepterHandle ?? (params.language === "ja" ? "バディ" : "Your buddy");
  if (params.language === "ja") {
    return {
      title: `${name}がリクエストを承認したよ`,
      body: "バディになったよ。一緒に空を撮ろう",
    };
  }
  return {
    title: `${name} approved your request.`,
    body: "You're buddies now. Capture the sky together.",
  };
}

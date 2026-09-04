/**
 * Pure decision logic for the "your invite was claimed" push notification (closes
 * D2 — see `dev-notes/virality-stickiness-assessment_2026-09-04.md` §6 / VISION.md's
 * TODO checklist: the inviter previously had no way to learn their invite was
 * claimed short of reopening the app). Kept free of `firebase-admin` for the same
 * reason as `buddyNotifications.ts`: this is exactly the kind of copy/logic mistake
 * that is trivial to get wrong and invisible in an emulator run.
 * `inviteNotificationStore.ts` is the thin Firestore/FCM-aware shell that wires this
 * to real data — deliberately separate from `buddyNotificationStore.ts` rather than
 * folded into it, since the trigger (an invite claim, not a post) and the recipient
 * (the inviter, not a buddy who already exists) are a different event shape.
 */

export interface InviteClaimedNotificationCopy {
  title: string;
  body: string;
}

export function inviteClaimedNotificationCopy(claimerHandle: string | null): InviteClaimedNotificationCopy {
  const name = claimerHandle ?? "Someone";
  return {
    title: "Your invite was claimed.",
    body: `${name} joined using your link — say hi in Buddies.`,
  };
}

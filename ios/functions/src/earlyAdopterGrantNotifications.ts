/**
 * Pure decision logic for early adopter grant push notifications: what the
 * notification says in each language.
 *
 * Kept free of `firebase-admin` for the same reason as `buddyNotifications.ts` /
 * `rateLimit.ts`: a text or translation mistake here is exactly the kind of thing
 * that is trivial to get wrong in an emulator run. `earlyAdopterGrantNotificationStore.ts`
 * is the thin Firestore/FCM-aware shell that wires this to real data.
 */

/** The two in-app languages Sky Grid supports server-side. Unknown/missing device
 * language data always falls back to English — never assume Japanese. */
export type DeviceLanguage = "en" | "ja";

export interface EarlyAdopterGrantNotificationCopy {
  title: string;
  body: string;
}

/**
 * House voice: short, declarative, no exclamation points (see `StreakMilestone`
 * headline copy, `MorningFollowUpScheduler`'s "Today's sky" / "Not captured yet.").
 * Japanese keeps the same understated, declarative register — casual sentence-final
 * particles, not exclamation-heavy tone.
 */
export function earlyAdopterGrantNotificationCopy(params: {
  language: DeviceLanguage;
}): EarlyAdopterGrantNotificationCopy {
  if (params.language === "ja") {
    return {
      title: "先着100人に入りました。",
      body: "Proを60日間プレゼントします。早くから使ってくれてありがとう。",
    };
  }
  // Default to English for unknown or missing language
  return {
    title: "You're one of our first 100.",
    body: "60 days of Pro, on us. Thanks for being here early.",
  };
}

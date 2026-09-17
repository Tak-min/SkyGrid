import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { advanceStreak, type BuddyStreak } from "./buddyStreaks.js";

const USERS = "users";
const POSTS = "posts";

/** Keeps the server-owned personal streak fields in sync with the post source of truth. */
export async function updatePersonalStreakForPost(
  db: Firestore,
  { uid, localDate }: { uid: string; localDate: string },
): Promise<void> {
  const userRef = db.collection(USERS).doc(uid);
  const postRef = userRef.collection(POSTS).doc(localDate);
  await db.runTransaction(async (transaction) => {
    const [user, post] = await Promise.all([transaction.get(userRef), transaction.get(postRef)]);
    if (!post.exists || !user.exists) return;

    const data = user.data() ?? {};
    const previous: BuddyStreak = {
      current: typeof data.streakCurrent === "number" ? data.streakCurrent : 0,
      longest: typeof data.streakLongest === "number" ? data.streakLongest : 0,
      lastMutualDate: typeof data.lastPostLocalDate === "string" ? data.lastPostLocalDate : undefined,
    };
    const next = advanceStreak(previous, localDate);
    if (
      next.current === previous.current
      && next.longest === previous.longest
      && next.lastMutualDate === previous.lastMutualDate
    ) return;

    transaction.update(userRef, {
      streakCurrent: next.current,
      streakLongest: next.longest,
      lastPostLocalDate: next.lastMutualDate,
      streakUpdatedAt: FieldValue.serverTimestamp(),
    });
  });
}

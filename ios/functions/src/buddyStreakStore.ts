import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { advanceStreak, type BuddyStreak } from "./buddyStreaks.js";

const FRIENDSHIPS = "friendships";
const USERS = "users";
const POSTS = "posts";

export interface UpdateBuddyStreaksParams {
  posterUid: string;
  localDate: string;
}

/** Updates every accepted, unblocked pair that became mutual for this post. */
export async function updateBuddyStreaksForPost(
  db: Firestore,
  { posterUid, localDate }: UpdateBuddyStreaksParams,
): Promise<void> {
  const friendships = await db.collection(FRIENDSHIPS).where("members", "array-contains", posterUid).get();

  await Promise.all(friendships.docs.map(async (friendship) => {
    const data = friendship.data();
    const buddyUid = activeBuddyUid(data, posterUid);
    if (!buddyUid) return;

    const buddyPost = db.collection(USERS).doc(buddyUid).collection(POSTS).doc(localDate);
    if (!(await buddyPost.get()).exists) return;

    await db.runTransaction(async (transaction) => {
      const [currentFriendship, currentBuddyPost] = await Promise.all([
        transaction.get(friendship.ref),
        transaction.get(buddyPost),
      ]);
      if (!currentFriendship.exists || !currentBuddyPost.exists) return;

      const currentData = currentFriendship.data();
      if (!currentData || !activeBuddyUid(currentData, posterUid)) return;

      const previous = streakFrom(currentData);
      const next = advanceStreak(previous, localDate);
      if (sameStreak(previous, next)) return;

      // Update, never set: a partial replacement could silently remove `blockedBy`,
      // which would make activeBuddy() in Firestore Rules deny the other member's read.
      const update: FirebaseFirestore.UpdateData<FirebaseFirestore.DocumentData> = {
        streakCurrent: next.current,
        streakLongest: next.longest,
        streakLastMutualDate: next.lastMutualDate,
      };
      if (!Object.prototype.hasOwnProperty.call(currentData, "streakTrackingSince")) {
        update.streakTrackingSince = FieldValue.serverTimestamp();
      }
      transaction.update(friendship.ref, update);
    });
  }));
}

function activeBuddyUid(data: FirebaseFirestore.DocumentData, posterUid: string): string | null {
  if (data.status !== "accepted" || !Array.isArray(data.blockedBy) || data.blockedBy.length !== 0) return null;
  if (!Array.isArray(data.members)) return null;
  const buddyUid = data.members.find((member: unknown) => typeof member === "string" && member !== posterUid);
  return typeof buddyUid === "string" ? buddyUid : null;
}

function streakFrom(data: FirebaseFirestore.DocumentData): BuddyStreak {
  return {
    current: typeof data.streakCurrent === "number" ? data.streakCurrent : 0,
    longest: typeof data.streakLongest === "number" ? data.streakLongest : 0,
    lastMutualDate: typeof data.streakLastMutualDate === "string" ? data.streakLastMutualDate : undefined,
  };
}

function sameStreak(left: BuddyStreak, right: BuddyStreak): boolean {
  return left.current === right.current
    && left.longest === right.longest
    && left.lastMutualDate === right.lastMutualDate;
}

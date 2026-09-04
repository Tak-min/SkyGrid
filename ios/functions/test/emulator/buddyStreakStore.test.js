const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const { updateBuddyStreaksForPost } = require("../../lib/buddyStreakStore.js");

admin.initializeApp({ projectId: "sky-grid-app" });
const db = admin.firestore();

async function reset() {
  await Promise.all(["users", "friendships"].map((collection) => db.recursiveDelete(db.collection(collection))));
}

async function makeFriendship({
  pairId = "a_b", members = ["a", "b"], status = "accepted", blockedBy = [], ...streak
} = {}) {
  await db.collection("friendships").doc(pairId).set({
    members,
    status,
    blockedBy,
    requestedBy: members[0],
    requestedByHandle: null,
    recipientHandle: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...streak,
  });
  return pairId;
}

async function post(uid, localDate) {
  await db.collection("users").doc(uid).collection("posts").doc(localDate).set({ ownerUid: uid });
  await updateBuddyStreaksForPost(db, { posterUid: uid, localDate });
}

async function friendship(pairId = "a_b") {
  return (await db.collection("friendships").doc(pairId).get()).data();
}

test("a solo post does not write a streak; the second same-day post starts it", async () => {
  await reset();
  await makeFriendship();

  await post("a", "2026-03-10");
  let data = await friendship();
  assert.equal(data.streakCurrent, undefined);
  assert.equal(data.streakTrackingSince, undefined);

  await post("b", "2026-03-10");
  data = await friendship();
  assert.equal(data.streakCurrent, 1);
  assert.equal(data.streakLongest, 1);
  assert.equal(data.streakLastMutualDate, "2026-03-10");
  assert.ok(data.streakTrackingSince);
  assert.ok(Object.hasOwn(data, "blockedBy"));
  assert.deepEqual(data.blockedBy, []);
});

test("consecutive mutual days increment while a gap resets", async () => {
  await reset();
  await makeFriendship();

  await post("a", "2026-03-10");
  await post("b", "2026-03-10");
  await post("a", "2026-03-11");
  await post("b", "2026-03-11");
  let data = await friendship();
  assert.equal(data.streakCurrent, 2);
  assert.equal(data.streakLongest, 2);

  await post("a", "2026-03-14");
  await post("b", "2026-03-14");
  data = await friendship();
  assert.equal(data.streakCurrent, 1);
  assert.equal(data.streakLongest, 2);
  assert.equal(data.streakLastMutualDate, "2026-03-14");
});

test("pending pairs are never written", async () => {
  await reset();
  await makeFriendship({ status: "pending" });

  await post("a", "2026-03-10");
  await post("b", "2026-03-10");
  const data = await friendship();
  assert.equal(data.streakCurrent, undefined);
  assert.equal(data.streakTrackingSince, undefined);
});

test("blocked pairs are skipped; unblocking allows a new mutual day to reset to one", async () => {
  await reset();
  await makeFriendship({ blockedBy: ["a"] });

  await post("a", "2026-03-10");
  await post("b", "2026-03-10");
  assert.equal((await friendship()).streakCurrent, undefined);

  await db.collection("friendships").doc("a_b").update({ blockedBy: [] });
  await post("a", "2026-03-11");
  await post("b", "2026-03-11");
  const data = await friendship();
  assert.equal(data.streakCurrent, 1);
  assert.equal(data.streakLastMutualDate, "2026-03-11");
  assert.ok(Object.hasOwn(data, "blockedBy"));
  assert.deepEqual(data.blockedBy, []);
});

test("concurrent same-day deliveries increment exactly once", async () => {
  await reset();
  await makeFriendship({
    streakCurrent: 1,
    streakLongest: 1,
    streakLastMutualDate: "2026-03-10",
    streakTrackingSince: admin.firestore.FieldValue.serverTimestamp(),
  });
  await db.collection("users").doc("a").collection("posts").doc("2026-03-11").set({ ownerUid: "a" });
  await db.collection("users").doc("b").collection("posts").doc("2026-03-11").set({ ownerUid: "b" });

  await Promise.all([
    updateBuddyStreaksForPost(db, { posterUid: "a", localDate: "2026-03-11" }),
    updateBuddyStreaksForPost(db, { posterUid: "b", localDate: "2026-03-11" }),
  ]);

  const data = await friendship();
  assert.equal(data.streakCurrent, 2);
  assert.equal(data.streakLongest, 2);
  assert.equal(data.streakLastMutualDate, "2026-03-11");
  assert.ok(Object.hasOwn(data, "blockedBy"));
});

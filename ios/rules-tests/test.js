// Verifies the cross-service reference in storage.rules' activeBuddy(): the Storage
// rule calls firestore.get()/exists() against the *Firestore* emulator to decide
// whether a buddy may view another user's posted photo. VISION.md flagged this as
// "要検証" (untested design assumption) — this suite exercises it against the real
// deployed rules files, not a re-implementation of the rule logic.
const fs = require("fs");
const path = require("path");
const assert = require("assert");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

// Must match the project the CLI launches the emulators under (see .firebaserc)
// so the Storage Rules Runtime's firestore.get()/exists() cross-service calls
// resolve against the same emulator-side Firestore data namespace as this test
// writes into via the JS SDK. A mismatched project ID here makes every
// cross-service lookup silently resolve to "not found" (see dev log).
const PROJECT_ID = "sky-grid-app";
const OWNER = "ownerUid";
const BUDDY = "buddyUid";
const STRANGER = "strangerUid";
const HANDLE_CLAIMER = "handleClaimer";
const LOCAL_DATE = "2026-07-31";

function postPath(uid = OWNER) {
  return `users/${uid}/posts/${LOCAL_DATE}`;
}

function imagePath(uid = OWNER) {
  return `posts/${uid}/${LOCAL_DATE}/abc123.jpg`;
}

function profileData(handle) {
  return {
    ...(handle ? { handle } : {}),
    displayName: "Sky Grid member",
    timezone: "Asia/Tokyo",
    wakeGoalMinutes: 420,
    streakCurrent: 0,
    streakLongest: 0,
    isPro: false,
    createdAt: new Date(),
  };
}

function relationshipId(a, b) {
  return a < b ? `${a}_${b}` : `${b}_${a}`;
}

let testEnv;

async function seedFriendship(overrides = {}) {
  const id = relationshipId(OWNER, BUDDY);
  const doc = {
    members: [OWNER, BUDDY].sort(),
    status: "accepted",
    requestedBy: OWNER,
    blockedBy: [],
    createdAt: new Date(),
    ...overrides,
  };
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("friendships").doc(id).set(doc);
  });
}

async function uploadAsOwner() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const bucket = context.storage().ref(imagePath());
    await bucket.put(Buffer.from("fake-jpeg-bytes"), {
      contentType: "image/jpeg",
    });
  });
}

async function seedPost(uid) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(postPath(uid)).set({ ownerUid: uid });
  });
}

before(async function () {
  this.timeout(20000);
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8180,
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, "..", "storage.rules"), "utf8"),
      host: "127.0.0.1",
      port: 9299,
    },
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

describe("storage.rules activeBuddy() cross-service reference", () => {
  it("lets an accepted buddy read the owner's post image", async () => {
    await seedFriendship({ status: "accepted" });
    await seedPost(BUDDY);
    await uploadAsOwner();
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertSucceeds(
      buddyCtx.storage().ref(imagePath()).getDownloadURL()
    );
  });

  it("blocks an accepted buddy before they post their own photo for the day", async () => {
    await seedFriendship({ status: "accepted" });
    await uploadAsOwner();
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertFails(buddyCtx.storage().ref(imagePath()).getDownloadURL());
  });

  it("lets the owner always read their own post image", async () => {
    await seedFriendship({ status: "accepted" });
    await uploadAsOwner();
    const ownerCtx = testEnv.authenticatedContext(OWNER);
    await assertSucceeds(
      ownerCtx.storage().ref(imagePath()).getDownloadURL()
    );
  });

  it("blocks a stranger with no friendship document", async () => {
    await seedFriendship({ status: "accepted" });
    await uploadAsOwner();
    const strangerCtx = testEnv.authenticatedContext(STRANGER);
    await assertFails(
      strangerCtx.storage().ref(imagePath()).getDownloadURL()
    );
  });

  it("blocks a buddy whose friendship is still pending (not accepted)", async () => {
    await seedFriendship({ status: "pending" });
    await uploadAsOwner();
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertFails(
      buddyCtx.storage().ref(imagePath()).getDownloadURL()
    );
  });

  it("blocks an accepted buddy once either side has blocked the relationship", async () => {
    await seedFriendship({ status: "accepted", blockedBy: [OWNER] });
    await uploadAsOwner();
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertFails(
      buddyCtx.storage().ref(imagePath()).getDownloadURL()
    );
  });

  it("blocks an unauthenticated read regardless of friendship state", async () => {
    await seedFriendship({ status: "accepted" });
    await uploadAsOwner();
    const anonCtx = testEnv.unauthenticatedContext();
    await assertFails(
      anonCtx.storage().ref(imagePath()).getDownloadURL()
    );
  });
});

describe("firestore.rules activeBuddy() (same predicate, Firestore side)", () => {
  it("lets an accepted buddy read the owner's profile doc", async () => {
    await seedFriendship({ status: "accepted" });
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection("users")
        .doc(OWNER)
        .set({
          handle: "owner",
          displayName: "Owner",
          timezone: "Asia/Tokyo",
          wakeGoalMinutes: 30,
          streakCurrent: 1,
          streakLongest: 1,
          isPro: false,
          createdAt: new Date(),
        });
    });
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertSucceeds(
      buddyCtx.firestore().collection("users").doc(OWNER).get()
    );
  });

  it("blocks a stranger from reading the owner's profile doc", async () => {
    await seedFriendship({ status: "accepted" });
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection("users")
        .doc(OWNER)
        .set({
          handle: "owner",
          displayName: "Owner",
          timezone: "Asia/Tokyo",
          wakeGoalMinutes: 30,
          streakCurrent: 1,
          streakLongest: 1,
          isPro: false,
          createdAt: new Date(),
        });
    });
    const strangerCtx = testEnv.authenticatedContext(STRANGER);
    await assertFails(
      strangerCtx.firestore().collection("users").doc(OWNER).get()
    );
  });

  it("blocks an accepted buddy from reading today's post before their own post", async () => {
    await seedFriendship({ status: "accepted" });
    await seedPost(OWNER);
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertFails(buddyCtx.firestore().doc(postPath()).get());
  });

  it("lets an accepted buddy read today's post after their own post", async () => {
    await seedFriendship({ status: "accepted" });
    await seedPost(OWNER);
    await seedPost(BUDDY);
    const buddyCtx = testEnv.authenticatedContext(BUDDY);
    await assertSucceeds(buddyCtx.firestore().doc(postPath()).get());
  });
});

describe("firestore.rules handle claims", () => {
  it("allows a first handle and profile to be created atomically", async () => {
    const handle = "fresh_handle";
    const firestore = testEnv.authenticatedContext(HANDLE_CLAIMER).firestore();
    const batch = firestore.batch();
    batch.set(firestore.collection("handles").doc(handle), {
      uid: HANDLE_CLAIMER,
      createdAt: new Date(),
    });
    batch.set(firestore.collection("users").doc(HANDLE_CLAIMER), profileData(handle));

    await assertSucceeds(batch.commit());
  });

  it("allows a first handle for a profile that already exists", async () => {
    const handle = "existing_profile";
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(HANDLE_CLAIMER).set(profileData());
    });

    const firestore = testEnv.authenticatedContext(HANDLE_CLAIMER).firestore();
    const batch = firestore.batch();
    batch.set(firestore.collection("handles").doc(handle), {
      uid: HANDLE_CLAIMER,
      createdAt: new Date(),
    });
    batch.update(firestore.collection("users").doc(HANDLE_CLAIMER), { handle });

    await assertSucceeds(batch.commit());
  });

  it("rejects a second handle for the same profile", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(HANDLE_CLAIMER).set(profileData("first_handle"));
      await context.firestore().collection("handles").doc("first_handle").set({
        uid: HANDLE_CLAIMER,
        createdAt: new Date(),
      });
    });

    const firestore = testEnv.authenticatedContext(HANDLE_CLAIMER).firestore();
    const batch = firestore.batch();
    batch.set(firestore.collection("handles").doc("second_handle"), {
      uid: HANDLE_CLAIMER,
      createdAt: new Date(),
    });
    batch.update(firestore.collection("users").doc(HANDLE_CLAIMER), { handle: "second_handle" });

    await assertFails(batch.commit());
  });
});

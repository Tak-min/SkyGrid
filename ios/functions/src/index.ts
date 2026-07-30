import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";

admin.initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 2 });

/**
 * Deletes one authenticated account. The callable deliberately accepts no UID:
 * `request.auth.uid` is the only identity ever acted on. Auth is deleted last, so a
 * transient Storage or Firestore failure leaves the caller able to retry safely.
 */
export const deleteAccount = onCall(
  {
    enforceAppCheck: true,
    consumeAppCheckToken: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in before deleting an account.");
    }

    const db = admin.firestore();
    const bucket = admin.storage().bucket();
    const userRef = db.collection("users").doc(uid);

    // Establish a server-side audit marker before cleanup. Each remaining step is
    // idempotent, so the authenticated caller can retry if any service is transiently unavailable.
    await userRef.set({ deletionRequestedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

    await bucket.deleteFiles({ prefix: `posts/${uid}/` });

    const [friendships, reportsByReporter, reportsBySubject, handles] = await Promise.all([
      db.collection("friendships").where("members", "array-contains", uid).get(),
      db.collection("reports").where("reporterUid", "==", uid).get(),
      db.collection("reports").where("subjectUid", "==", uid).get(),
      db.collection("handles").where("uid", "==", uid).get(),
    ]);

    const writer = db.bulkWriter();
    for (const document of friendships.docs) writer.delete(document.ref);
    for (const document of reportsByReporter.docs) writer.delete(document.ref);
    for (const document of reportsBySubject.docs) writer.delete(document.ref);
    for (const document of handles.docs) writer.delete(document.ref);
    await writer.close();

    // recursiveDelete removes nested post/device documents; deleting only the parent
    // would leave those subcollections intact.
    await db.recursiveDelete(userRef);
    await admin.auth().deleteUser(uid);

    return { deleted: true };
  }
);

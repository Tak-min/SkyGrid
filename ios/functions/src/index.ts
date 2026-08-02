import * as admin from "firebase-admin";
import { timingSafeEqual } from "node:crypto";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import {
  FREE_SUBSCRIPTION,
  nextSubscriptionSnapshot,
  planForProductID,
  type RevenueCatSubscriptionEvent,
  type SubscriptionSnapshot,
} from "./subscriptionState.js";

admin.initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 2 });
const revenueCatWebhookAuthorization = defineSecret("REVENUECAT_WEBHOOK_AUTHORIZATION");

/**
 * Deletes one authenticated account. The callable deliberately accepts no UID:
 * `request.auth.uid` is the only identity ever acted on. Auth is deleted last, so a
 * transient Storage or Firestore failure leaves the caller able to retry safely.
 *
 * App Check is enforced but tokens are NOT consumed. `consumeAppCheckToken` only
 * populates `request.app.alreadyConsumed` — firebase-functions never rejects a
 * request on it — so it provided no real replay protection, while forcing the
 * client to request limited-use tokens that the App Check debug provider cannot
 * mint in this project (the SDK falls back to a placeholder token that this
 * callable then rejects as an undecodable JWT). Replay resistance instead comes
 * from this operation being idempotent and scoped only to the verified caller.
 */
export const deleteAccount = onCall(
  {
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in before deleting an account.");
    }

    const db = admin.firestore();
    const bucket = admin.storage().bucket();
    const userRef = db.collection("users").doc(uid);
    const entitlementRef = db.collection("entitlements").doc(uid);

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
    writer.delete(entitlementRef);
    await writer.close();

    // recursiveDelete removes nested post/device documents; deleting only the parent
    // would leave those subcollections intact.
    await db.recursiveDelete(userRef);

    // A retry after a partially completed deletion must succeed, not 500. A
    // Firebase ID token stays verifiable until it expires, so the client can
    // legitimately reach this line again with the Auth user already gone.
    try {
      await admin.auth().deleteUser(uid);
    } catch (error: unknown) {
      if ((error as { code?: string }).code !== "auth/user-not-found") {
        logger.error("Failed to delete auth user.", { uid, error });
        throw error;
      }
    }

    return { deleted: true };
  }
);

/**
 * Mirrors RevenueCat lifecycle events into entitlements/{firebaseUid}.
 * The endpoint uses the Authorization value configured on the RevenueCat webhook
 * integration. It is intentionally not protected by Firebase App Check: webhook
 * calls originate from RevenueCat rather than an app-attested client.
 *
 * iOS configures RevenueCat with the Firebase UID as its App User ID, so the
 * server does not need to accept a client-provided identity. The mirror supports
 * reporting and support tooling only; the app continues to verify entitlement
 * access with RevenueCat before it unlocks Pro.
 */
export const revenueCatWebhook = onRequest(
  {
    secrets: [revenueCatWebhookAuthorization],
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method Not Allowed");
      return;
    }

    if (!hasExpectedAuthorization(
      request.get("authorization"),
      revenueCatWebhookAuthorization.value(),
    )) {
      response.status(401).send("Unauthorized");
      return;
    }

    const event = eventFromPayload(request.body);
    if (!event) {
      response.status(400).send("Invalid RevenueCat event");
      return;
    }

    const plan = planForProductID(event.product_id);
    // An event for an unrelated RevenueCat product must never revoke or grant
    // Sky Grid access. Every supported lifecycle event carries one of the three
    // canonical paid product identifiers, so product recognition is the gate.
    const affectsSkyGridEntitlement = plan !== null;
    if (!affectsSkyGridEntitlement) {
      response.status(200).json({ ignored: true });
      return;
    }

    const uid = event.app_user_id;
    const eventID = event.id;
    const eventTimestamp = event.event_timestamp_ms;
    if (!uid || !eventID || !Number.isFinite(eventTimestamp)) {
      response.status(400).send("Missing RevenueCat identity or event metadata");
      return;
    }
    const acceptedEventTimestamp = eventTimestamp as number;

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const entitlementRef = db.collection("entitlements").doc(uid);
    await admin.firestore().runTransaction(async (transaction) => {
      // An account-deletion retry or a delayed webhook must not recreate data for
      // an account that no longer exists.
      const user = await transaction.get(userRef);
      if (!user.exists) return;
      const snapshot = await transaction.get(entitlementRef);
      const data = snapshot.data();
      const latestTimestamp = typeof data?.latestEventTimestampMs === "number"
        ? data.latestEventTimestampMs
        : -1;

      // RevenueCat retries retain both event ID and timestamp. Ignoring older or
      // duplicate deliveries prevents an old cancellation/expiration from
      // overwriting a newer renewal.
      if (acceptedEventTimestamp <= latestTimestamp) {
        return;
      }

      const current = snapshotFrom(data);
      const next = nextSubscriptionSnapshot(current, event);
      transaction.set(entitlementRef, {
        ...next,
        latestEventID: eventID,
        latestEventTimestampMs: acceptedEventTimestamp,
        lastEventType: event.type,
        productID: event.product_id ?? null,
        expirationAt: typeof event.expiration_at_ms === "number"
          ? admin.firestore.Timestamp.fromMillis(event.expiration_at_ms)
          : null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });

    logger.info("RevenueCat entitlement mirror updated", {
      eventID,
      eventType: event.type,
      hasRecognisedProduct: plan !== null,
    });
    response.status(200).json({ received: true });
  },
);

interface RevenueCatWebhookPayload {
  event?: RevenueCatSubscriptionEvent & {
    app_user_id?: string;
    id?: string;
    event_timestamp_ms?: number;
    expiration_at_ms?: number | null;
  };
}

function eventFromPayload(payload: unknown): (RevenueCatSubscriptionEvent & {
  app_user_id?: string;
  id?: string;
  event_timestamp_ms?: number;
  expiration_at_ms?: number | null;
}) | null {
  if (!payload || typeof payload !== "object") return null;
  const event = (payload as RevenueCatWebhookPayload).event;
  return event && typeof event.type === "string" ? event : null;
}

function snapshotFrom(data: FirebaseFirestore.DocumentData | undefined): SubscriptionSnapshot {
  const plan = data?.plan;
  if (plan === "monthly" || plan === "annual" || plan === "lifetime") {
    return {
      plan,
      isPro: true,
      willRenew: typeof data?.willRenew === "boolean" ? data.willRenew : plan !== "lifetime",
    };
  }
  return FREE_SUBSCRIPTION;
}

function hasExpectedAuthorization(actual: string | undefined, expected: string): boolean {
  if (!actual || !expected) return false;
  const actualBytes = Buffer.from(actual);
  const expectedBytes = Buffer.from(expected);
  return actualBytes.length === expectedBytes.length && timingSafeEqual(actualBytes, expectedBytes);
}

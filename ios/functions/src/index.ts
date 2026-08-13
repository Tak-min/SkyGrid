import * as admin from "firebase-admin";
import { timingSafeEqual } from "node:crypto";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import {
  FREE_SUBSCRIPTION,
  nextSubscriptionSnapshot,
  planForProductID,
  type RevenueCatSubscriptionEvent,
  type SubscriptionSnapshot,
} from "./subscriptionState.js";
import { formatInviteCode } from "./invites.js";
import {
  AccountUnavailableError,
  CodeExhaustionError,
  INVITE_COLLECTION,
  INVITE_RATE_LIMIT_COLLECTION,
  MalformedFriendshipError,
  MissingHandleError,
  canonicalCode,
  claimInvite,
  codeForLog,
  consumeRateLimit,
  createInviteForUser,
  previewInviteCode,
  revokeInviteDocument,
} from "./inviteStore.js";
import type { RateLimitedAction } from "./rateLimit.js";
import { notifyBuddiesOfPost } from "./buddyNotificationStore.js";

admin.initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 2 });
const revenueCatWebhookAuthorization = defineSecret("REVENUECAT_WEBHOOK_AUTHORIZATION");
const inviteCallableOptions = { enforceAppCheck: true, region: "asia-northeast1" } as const;

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

    const [
      friendships,
      reportsByReporter,
      reportsBySubject,
      handles,
      createdInvites,
      claimedInvites,
    ] = await Promise.all([
      db.collection("friendships").where("members", "array-contains", uid).get(),
      db.collection("reports").where("reporterUid", "==", uid).get(),
      db.collection("reports").where("subjectUid", "==", uid).get(),
      db.collection("handles").where("uid", "==", uid).get(),
      db.collection(INVITE_COLLECTION).where("creatorUid", "==", uid).get(),
      db.collection(INVITE_COLLECTION).where("claimedByUid", "==", uid).get(),
    ]);

    const writer = db.bulkWriter();
    const inviteRedactionFailures: unknown[] = [];
    for (const document of friendships.docs) writer.delete(document.ref);
    for (const document of reportsByReporter.docs) writer.delete(document.ref);
    for (const document of reportsBySubject.docs) writer.delete(document.ref);
    for (const document of handles.docs) writer.delete(document.ref);

    // Links this account issued are its own data, and are already dead — a claim
    // against them resolves `unknown` once this profile is gone. Deleting them is
    // what stops orphaned invites accumulating.
    const deletedInviteIDs = new Set(createdInvites.docs.map((document) => document.id));
    for (const document of createdInvites.docs) writer.delete(document.ref);

    // Links this account *claimed* belong to somebody else. Deleting one would
    // destroy that person's record and, worse, make the code read as `unknown`
    // again — i.e. spendable-looking. Redacting the foreign key instead leaves it
    // `claimed` by nobody, which `resolveClaim` already treats as unusable.
    for (const document of claimedInvites.docs) {
      // A document in both sets would be deleted and updated in the same flush, and
      // the update would fail NOT_FOUND. `ownInvite` should make this impossible;
      // do not depend on that.
      if (deletedInviteIDs.has(document.id)) continue;
      // The first write in this function that can genuinely fail — every other one is
      // an idempotent delete. NOT_FOUND means the invite's creator deleted it
      // concurrently, which is already the desired result. Any other failure is kept
      // and rethrown after BulkWriter drains so Auth remains available for a retry.
      writer.update(document.ref, { claimedByUid: null }).catch((error: unknown) => {
        if (isNotFoundError(error)) {
          logger.warn("Claimed invite disappeared during account deletion.", {
            uid,
            code: codeForLog(document.id),
          });
          return;
        }
        inviteRedactionFailures.push(error);
      });
    }

    writer.delete(db.collection(INVITE_RATE_LIMIT_COLLECTION).doc(uid));
    writer.delete(entitlementRef);
    await writer.close();
    if (inviteRedactionFailures.length > 0) {
      const error = inviteRedactionFailures[0];
      logger.error("Could not redact claimed invites during account deletion.", {
        uid,
        errorCode: errorCodeForLog(error),
      });
      throw error;
    }

    // recursiveDelete removes nested post/device/postNotifications documents;
    // deleting only the parent would leave those subcollections intact.
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
 * Buddy invite links.
 *
 * Four callables rather than Security Rules, for three reasons that are recorded here
 * because the rules-only design keeps looking attractive until each one is stated:
 *
 * 1. `friendships/{pairId}` is keyed by `sorted(uidA, uidB)`, so at the moment a link
 *    is created the second UID does not exist and the document cannot be pre-written.
 * 2. A rule permissive enough for a recipient to read `invites/{code}` is a rule
 *    permissive enough for anyone signed in to read any code — a Firestore-native
 *    enumeration oracle with no rate limit in front of it.
 * 3. Creating the pair and spending the code have to be one atomic act. Split them and
 *    a client can take the pair without spending the code, or spend it without pairing.
 *
 * That third point is the same call `imageDownloadURL` below already made: a predicate
 * spanning several documents belongs on the server.
 *
 * **No domain branch here ever answers `not-found` or `permission-denied`.** Every
 * normal outcome that depends on whether a code exists is a 200 carrying a
 * `state`/`outcome` field. Caller-state errors are decided before the code is read;
 * infrastructure failures surface only as a generic `internal` response whose logs
 * contain neither the raw Firestore error nor the full code.
 */

/** One budget unit, spent before the code is read so the charge cannot depend on it. */
async function enforceRateLimit(uid: string, action: RateLimitedAction, nowMs: number): Promise<void> {
  const allowed = await consumeRateLimit(admin.firestore(), uid, action, nowMs);
  if (!allowed) {
    throw new HttpsError("resource-exhausted", "Too many requests. Try again in a little while.");
  }
}

function requireCaller(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return uid;
}

/**
 * Firestore error messages can embed a full document path, which for `invites` would
 * put the secret code into Cloud Logging. Keep only the machine-readable status.
 */
function errorCodeForLog(error: unknown): string | number {
  const code = (error as { code?: unknown })?.code;
  return typeof code === "string" || typeof code === "number" ? code : "unknown";
}

function isNotFoundError(error: unknown): boolean {
  const code = (error as { code?: unknown })?.code;
  return code === 5 || code === "not-found";
}

/**
 * Issues, or re-issues, the caller's buddy link.
 *
 * Returns an existing live link unless `fresh` is true. See `createInviteForUser` for
 * why minting on every call would silently revoke links users had already sent.
 */
export const createInvite = onCall(inviteCallableOptions, async (request) => {
  const uid = requireCaller(request.auth?.uid);
  const nowMs = Date.now();
  await enforceRateLimit(uid, "create", nowMs);

  try {
    const result = await createInviteForUser(admin.firestore(), uid, nowMs, {
      fresh: request.data?.fresh === true,
    });
    // `formattedCode` is served alongside the raw code so the UI can show a typeable
    // form without parsing the URL, and so the grouping can change server-side.
    return { ...result, formattedCode: formatInviteCode(result.code) };
  } catch (error: unknown) {
    if (error instanceof AccountUnavailableError) {
      throw new HttpsError("failed-precondition", "This account is being deleted.");
    }
    if (error instanceof MissingHandleError) {
      throw new HttpsError("failed-precondition", "Choose a handle before inviting a buddy.");
    }
    if (error instanceof CodeExhaustionError) {
      logger.error("Exhausted invite code attempts.", { uid });
      throw new HttpsError("internal", "Could not create an invite link.");
    }
    throw error;
  }
});

/**
 * Reports what a code is, without spending it, so the app can say who invited you
 * before it acts. Never throws for a code-dependent reason — an unrecognised code is a
 * 200 with `state: "unknown"`, identical in shape to every other dead-end.
 */
export const previewInvite = onCall(inviteCallableOptions, async (request) => {
  const uid = requireCaller(request.auth?.uid);
  const nowMs = Date.now();
  await enforceRateLimit(uid, "preview", nowMs);

  if (typeof request.data?.code !== "string") {
    throw new HttpsError("invalid-argument", "Invalid request.");
  }
  // A string that cannot be a code takes the same path as one that simply is not in
  // the collection. `normalizeInviteCode` is deterministic and runnable by anyone, so
  // this leaks nothing either way — it just keeps every code-shaped input on one path.
  const code = canonicalCode(request.data.code);
  if (!code) return { state: "unknown" };

  return previewInviteCode(admin.firestore(), code, uid, nowMs);
});

/** Spends a code and pairs the two people, atomically. See `claimInvite` in the store. */
export const claimInviteCode = onCall(inviteCallableOptions, async (request) => {
  const uid = requireCaller(request.auth?.uid);
  const nowMs = Date.now();
  await enforceRateLimit(uid, "claim", nowMs);

  if (typeof request.data?.code !== "string") {
    throw new HttpsError("invalid-argument", "Invalid request.");
  }
  const code = canonicalCode(request.data.code);
  if (!code) return { outcome: "unknown" };

  try {
    return await claimInvite(admin.firestore(), { code, callerUid: uid, nowMs });
  } catch (error: unknown) {
    if (error instanceof AccountUnavailableError) {
      throw new HttpsError("failed-precondition", "This account is being deleted.");
    }
    if (error instanceof MissingHandleError) {
      throw new HttpsError("failed-precondition", "Choose a handle before joining a buddy.");
    }
    if (error instanceof MalformedFriendshipError) {
      logger.error("Malformed friendship blocked an invite claim.", {
        uid,
        category: "malformed_friendship",
      });
      return { outcome: "unknown" as const };
    }
    logger.error("Invite claim failed.", {
      uid,
      code: codeForLog(code),
      errorCode: errorCodeForLog(error),
    });
    throw new HttpsError("internal", "Could not complete the invite.");
  }
});

/**
 * Takes one of the caller's own links out of circulation. Not rate limited: its
 * response is identical for "no such code" and "not your code", so there is nothing
 * to enumerate through it.
 */
export const revokeInvite = onCall(inviteCallableOptions, async (request) => {
  const uid = requireCaller(request.auth?.uid);

  if (typeof request.data?.code !== "string") {
    throw new HttpsError("invalid-argument", "Invalid request.");
  }
  const code = canonicalCode(request.data.code);
  if (!code) return { revoked: false };

  return revokeInviteDocument(admin.firestore(), { code, callerUid: uid });
});

/**
 * Gives an eligible buddy the bytes for one exact photo.
 *
 * Cloud Storage Rules support direct owner reads reliably in production, but its
 * Firestore cross-service lookups did not evaluate consistently for this app's
 * App Check-enforced bucket. Keeping the friendship/mutual-post predicate here
 * makes the server the single authority for shared bytes. Captures are capped at
 * 2 MB by Storage Rules, so the base64 callable response stays below Functions'
 * response limit without granting the runtime service account IAM signBlob access.
 */
export const imageDownloadURL = onCall(
  { enforceAppCheck: true },
  async (request) => {
    const callerUID = request.auth?.uid;
    if (!callerUID) {
      throw new HttpsError("unauthenticated", "Sign in before viewing a photo.");
    }

    const requestedPath = typeof request.data?.path === "string" ? request.data.path : "";
    const parsed = parsePostImagePath(requestedPath);
    if (!parsed) {
      throw new HttpsError("invalid-argument", "Invalid photo path.");
    }

    const db = admin.firestore();
    const postRef = db.doc(`users/${parsed.ownerUID}/posts/${parsed.localDate}`);
    const post = await postRef.get();
    const postData = post.data();
    if (!post.exists || postData?.ownerUid !== parsed.ownerUID
      || (postData.imagePath !== requestedPath && postData.thumbPath !== requestedPath)) {
      throw new HttpsError("not-found", "Photo is unavailable.");
    }

    if (callerUID !== parsed.ownerUID) {
      const pairID = relationshipID(callerUID, parsed.ownerUID);
      const [relationship, callerPost] = await Promise.all([
        db.doc(`friendships/${pairID}`).get(),
        db.doc(`users/${callerUID}/posts/${parsed.localDate}`).get(),
      ]);
      const relationshipData = relationship.data();
      const members = relationshipData?.members;
      const blockedBy = relationshipData?.blockedBy;
      const callerPostData = callerPost.data();
      const isActiveBuddy = relationship.exists
        && Array.isArray(members)
        && members.length === 2
        && members.includes(callerUID)
        && members.includes(parsed.ownerUID)
        && relationshipData?.status === "accepted"
        && Array.isArray(blockedBy)
        && blockedBy.length === 0;
      const hasPostedToday = callerPost.exists && callerPostData?.ownerUid === callerUID;
      if (!isActiveBuddy || !hasPostedToday) {
        throw new HttpsError("permission-denied", "Capture your own sky before viewing this photo.");
      }
    }

    const file = admin.storage().bucket().file(requestedPath);
    const [exists] = await file.exists();
    if (!exists) {
      throw new HttpsError("not-found", "Photo bytes are not ready yet.");
    }
    const [bytes] = await file.download();
    return { base64: bytes.toString("base64") };
  },
);

function parsePostImagePath(path: string): { ownerUID: string; localDate: string } | null {
  const match = /^posts\/([^/]+)\/(\d{4}-\d{2}-\d{2})\/[A-Za-z0-9-]+(?:_thumb)?\.jpg$/.exec(path);
  return match ? { ownerUID: match[1], localDate: match[2] } : null;
}

function relationshipID(first: string, second: string): string {
  return first < second ? `${first}_${second}` : `${second}_${first}`;
}

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

/**
 * The delivery half of SkyGrid's core mutual-reveal mechanic: a buddy finding out a
 * post happened without reopening the app. Notifies every accepted, unblocked buddy
 * of the poster — see `buddyNotificationStore.ts` for the marker/quiet-hours/
 * stale-token logic this only triggers.
 *
 * `region: "asia-northeast1"` is required, not a style choice: the Firestore database
 * is single-region `asia-northeast1` (`dev-notes/firebase-backend-provisioning_2026-07-29.md`),
 * and a Firestore-triggered (Eventarc) function must run in the same region as the
 * database it watches — unlike the `onCall`/`onRequest` functions above, whose region
 * only affects client latency. `retry: false`: `notifyBuddiesOfPost` already claims an
 * idempotency marker before sending anything and is documented to never throw, so a
 * retried delivery of the same event would only ever hit the "already claimed" path —
 * there is nothing a retry could fix that this function's own error handling doesn't
 * already cover, and retrying would just extend how long a truly stuck event lingers.
 */
export const onBuddyPostCreated = onDocumentCreated(
  {
    document: "users/{uid}/posts/{localDate}",
    region: "asia-northeast1",
    retry: false,
  },
  async (event) => {
    const { uid: posterUid, localDate } = event.params;
    try {
      await notifyBuddiesOfPost(admin.firestore(), admin.messaging(), {
        posterUid,
        localDate,
        nowMs: Date.now(),
      });
    } catch (error: unknown) {
      // `notifyBuddiesOfPost` is documented to never throw; this is a last-resort net
      // so a truly unexpected failure here can never surface as a failed trigger for
      // a post that already succeeded and is not going anywhere.
      logger.error("Unhandled error notifying buddies of a post.", { posterUid, localDate, error });
    }
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

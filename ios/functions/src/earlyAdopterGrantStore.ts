import { FieldValue, type Firestore } from "firebase-admin/firestore";

const CAMPAIGNS = "campaigns";
const EARLY_ADOPTER_GRANTS = "earlyAdopterGrants";
const ENTITLEMENTS = "entitlements";
const CAMPAIGN_ID = "earlyAdopter100";
const CAMPAIGN_LIMIT = 100;

const REVENUECAT_BASE_URL = "https://api.revenuecat.com/v1";
const REVENUECAT_ENTITLEMENT_ID = "premium";
const GRANT_DURATION_DAYS = 60;
const GRANT_DURATION_MS = GRANT_DURATION_DAYS * 24 * 60 * 60 * 1000;

/**
 * Fill in known QA/developer uids here before running the CLI in `--execute` mode.
 * Left empty deliberately — see the loud runtime warning in `tools/grantEarlyAdopter.ts`,
 * which refuses to run non-dry-run with an empty list without an explicit override, since
 * an empty denylist risks granting to the developer's own test accounts.
 */
export const QA_DENYLIST: string[] = [
  // Owner's own real-device test account (uid captured from the physical
  // device console at launch time, 2026-09-17). Prevents the owner's own
  // testing from consuming one of the 100 real early-adopter slots.
  "9sMUrQuY8fbANparjixyy2qPVv02",
];

export type ClaimResult = "claimed" | "resume" | "already" | "paused" | "exhausted";
export type GrantSource = "live" | "batch";

/**
 * Reserves one of the 100 total early-adopter slots for `uid`, atomically, across both
 * the retroactive batch tool and the live first-post trigger. The counter tracks CLAIMED
 * slots (pending + granted + failed), not just granted ones — an in-flight grant must
 * reserve its slot immediately, otherwise two concurrent claims near the 100th slot could
 * both proceed to call RevenueCat before either finishes.
 *
 * Deliberately does NOT try to detect "is this the user's first post" — every post
 * creation should call this, and the `earlyAdopterGrants/{uid}` doc's existence (checked
 * here, inside the transaction) is what makes only the true first successful claim count.
 * Detecting "first post" any other way (counting posts, checking creation order) would
 * itself become a race condition; uniqueness-via-`tx.create()` cannot.
 */
export async function claimEarlyAdopterSlot(
  db: Firestore,
  uid: string,
  { source, runId }: { source: GrantSource; runId?: string },
): Promise<ClaimResult> {
  const grantRef = db.collection(EARLY_ADOPTER_GRANTS).doc(uid);
  const counterRef = db.collection(CAMPAIGNS).doc(CAMPAIGN_ID);

  return db.runTransaction(async (transaction) => {
    // Both reads before any write, per Firestore transaction rules.
    const [grantSnap, counterSnap] = await Promise.all([
      transaction.get(grantRef),
      transaction.get(counterRef),
    ]);

    if (grantSnap.exists) {
      // A previous invocation may have reserved the slot and then lost its process
      // before (or just after) the RevenueCat response. Re-running the grant is safe
      // because every attempt uses the immutable planned expiry stored below.
      return grantSnap.data()?.status === "pending" ? "resume" : "already";
    }

    // A missing counter doc means the campaign was never provisioned in this
    // environment — fail loud (throw) rather than silently treating it as "0 claimed
    // so far", which would let an unprovisioned deploy hand out unlimited grants.
    if (!counterSnap.exists) {
      throw new Error(
        `campaigns/${CAMPAIGN_ID} does not exist — create it with { claimedCount: 0, limit: ${CAMPAIGN_LIMIT} } before this trigger can run`,
      );
    }

    const counter = counterSnap.data() as {
      claimedCount?: unknown;
      limit?: unknown;
      phase?: unknown;
      closedAt?: unknown;
    };
    if (!Number.isInteger(counter.claimedCount) || !Number.isInteger(counter.limit) ||
        (counter.claimedCount as number) < 0 || (counter.limit as number) < 1 ||
        (counter.limit as number) > CAMPAIGN_LIMIT ||
        !["backfill", "live", "closed"].includes(counter.phase as string)) {
      throw new Error(
        `campaigns/${CAMPAIGN_ID} must contain integer claimedCount >= 0, limit between 1 and ${CAMPAIGN_LIMIT}, and a valid phase`,
      );
    }
    if (counter.phase === "closed") return "exhausted";
    if (source === "live" && counter.phase !== "live") return "paused";
    if ((counter.claimedCount as number) >= (counter.limit as number) ||
        (counter.claimedCount as number) >= CAMPAIGN_LIMIT) {
      return "exhausted";
    }

    const plannedExpiresAtMs = Date.now() + GRANT_DURATION_MS;
    transaction.create(grantRef, {
      uid,
      source,
      ...(runId ? { runId } : {}),
      status: "pending",
      entitlement: REVENUECAT_ENTITLEMENT_ID,
      plannedExpiresAtMs,
      createdAt: FieldValue.serverTimestamp(),
    });
    const nextClaimedCount = (counter.claimedCount as number) + 1;
    transaction.update(counterRef, {
      claimedCount: FieldValue.increment(1),
      ...(nextClaimedCount >= (counter.limit as number) || nextClaimedCount >= CAMPAIGN_LIMIT
        ? { phase: "closed", closedAt: FieldValue.serverTimestamp() }
        : {}),
    });

    return "claimed";
  });
}

/**
 * Cheap, no-external-call eligibility check shared by the live trigger and the batch
 * CLI: has a handle, not on the QA denylist, not already Premium. Reads the
 * `entitlements/{uid}` Firestore mirror (written by the RevenueCat webhook, see
 * `index.ts`'s `snapshotFrom`/`isPro`) rather than calling RevenueCat directly — the live
 * trigger must never make an external call before it has actually claimed a slot.
 *
 * Does NOT check whether a grant doc already exists for `uid` — that is
 * `claimEarlyAdopterSlot`'s job (returns `"already"`), not this function's.
 */
export async function isEligible(db: Firestore, uid: string): Promise<boolean> {
  if (QA_DENYLIST.includes(uid)) return false;

  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists || !userSnap.data()?.handle) return false;

  const entitlementSnap = await db.collection(ENTITLEMENTS).doc(uid).get();
  if (entitlementSnap.data()?.isPro === true) return false;

  return true;
}

// RevenueCat API helper — same auth/retry shape the original CLI used.
type FetchLike = typeof fetch;

async function revenueCatFetch(
  method: string,
  path: string,
  apiKey: string,
  body?: Record<string, unknown>,
  fetchImpl: FetchLike = fetch,
): Promise<void> {
  const response = await fetchImpl(`${REVENUECAT_BASE_URL}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (response.status < 200 || response.status >= 300) {
    const error = new Error(`RevenueCat request failed with status ${response.status}`) as Error & { status?: number };
    error.status = response.status;
    throw error;
  }
}

async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries = 3,
  sleep: (milliseconds: number) => Promise<void> = (milliseconds) =>
    new Promise((resolve) => setTimeout(resolve, milliseconds)),
): Promise<T> {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      const status = (error as { status?: number }).status;
      // Transport errors have no status. Retrying them is safe here because the
      // promotional grant always carries the same immutable end_time_ms.
      const isRetryable = status === undefined || status === 429 || (status >= 500 && status < 600);
      if (!isRetryable || attempt === maxRetries) throw error;
      await sleep(3 ** attempt * 500);
    }
  }
  throw new Error("Max retries exceeded");
}

/**
 * Grants 60 days of the `premium` entitlement via RevenueCat's promotional-grant
 * endpoint. Sends `end_time_ms` ONLY — never `duration`. Confirmed directly against the
 * RevenueCat dashboard's own "Grant entitlement" UI: the Duration presets are day / three
 * days / week / month / three months / six months / year / lifetime, with "Until date" as
 * a separate, mutually-exclusive mode. There is no 60-day preset, and duration-preset and
 * until-date are not meant to be combined — so `end_time_ms` (which the UI calls "Until
 * date") is the only correct way to express this grant, independent of whatever
 * precedence an undocumented combination might have.
 */
export async function grantEntitlement(
  uid: string,
  expiresAtMs: number,
  options: {
    apiKey?: string;
    fetchImpl?: FetchLike;
    sleep?: (milliseconds: number) => Promise<void>;
  } = {},
): Promise<void> {
  const apiKey = options.apiKey ?? process.env.REVENUECAT_SECRET_API_KEY;
  if (!apiKey) throw new Error("REVENUECAT_SECRET_API_KEY environment variable not set");
  if (!Number.isFinite(expiresAtMs) || expiresAtMs <= 0) throw new Error("A valid grant expiry is required");

  await retryWithBackoff(
    () => revenueCatFetch(
      "POST",
      `/subscribers/${encodeURIComponent(uid)}/entitlements/${REVENUECAT_ENTITLEMENT_ID}/promotional`,
      apiKey,
      { end_time_ms: expiresAtMs },
      options.fetchImpl,
    ),
    3,
    options.sleep,
  );
}

/** Revokes a previously-granted promotional entitlement. Used by the CLI's `--revoke*` modes. */
export async function revokeEntitlement(
  uid: string,
  options: { apiKey?: string; fetchImpl?: FetchLike; sleep?: (milliseconds: number) => Promise<void> } = {},
): Promise<void> {
  const apiKey = options.apiKey ?? process.env.REVENUECAT_SECRET_API_KEY;
  if (!apiKey) throw new Error("REVENUECAT_SECRET_API_KEY environment variable not set");
  await retryWithBackoff(
    () => revenueCatFetch(
      "POST",
      `/subscribers/${encodeURIComponent(uid)}/entitlements/${REVENUECAT_ENTITLEMENT_ID}/revoke_promotionals`,
      apiKey,
      undefined,
      options.fetchImpl,
    ),
    3,
    options.sleep,
  );
}

/**
 * Phase 2 of a claimed slot: call RevenueCat, then record the outcome. Shared by the live
 * trigger and the batch CLI so there is exactly one implementation. RevenueCat/API
 * failures become `status:"failed"`; Firestore failures may still throw so Eventarc can
 * resume a pending claim. Repeating that external call is safe because every attempt
 * uses the immutable `plannedExpiresAtMs`, never a fresh "60 days from retry" deadline.
 * Nothing auto-releases a slot: a timeout may mean RevenueCat succeeded even though its
 * response was lost, so failed records must be reconciled before manual retry.
 */
export async function completeGrant(
  db: Firestore,
  uid: string,
  options: { apiKey?: string; fetchImpl?: FetchLike; sleep?: (milliseconds: number) => Promise<void> } = {},
): Promise<"granted" | "failed"> {
  const grantRef = db.collection(EARLY_ADOPTER_GRANTS).doc(uid);
  const grantSnapshot = await grantRef.get();
  if (!grantSnapshot.exists) throw new Error("Cannot complete an unclaimed early-adopter grant");
  const grant = grantSnapshot.data();
  if (grant?.status === "granted") return "granted";
  if (grant?.status !== "pending" && grant?.status !== "failed") {
    throw new Error(`Cannot complete an early-adopter grant in status ${String(grant?.status)}`);
  }
  const plannedExpiresAtMs = grant?.plannedExpiresAtMs;
  if (!Number.isFinite(plannedExpiresAtMs)) {
    // Never invent a new deadline while recovering a legacy/partial record: doing so
    // could silently extend a grant whose RevenueCat response was lost.
    throw new Error("Grant has no plannedExpiresAtMs; reconcile it before retrying");
  }

  try {
    await grantEntitlement(uid, plannedExpiresAtMs, options);
    await db.runTransaction(async (transaction) => {
      const latest = await transaction.get(grantRef);
      if (latest.data()?.status === "revoked") {
        throw new Error("Grant was revoked while completion was in progress");
      }
      transaction.update(grantRef, {
        status: "granted",
        grantedAt: FieldValue.serverTimestamp(),
        expiresAtMs: plannedExpiresAtMs,
        error: FieldValue.delete(),
        failedAt: FieldValue.delete(),
      });
    });
    return "granted";
  } catch (error) {
    const message = String(error instanceof Error ? error.message : error).slice(0, 300);
    const finalStatus = await db.runTransaction(async (transaction) => {
      const latest = await transaction.get(grantRef);
      // A slower failed attempt must never overwrite a concurrent successful one.
      if (latest.data()?.status === "granted") return "granted" as const;
      if (latest.data()?.status === "revoked") return "failed" as const;
      transaction.update(grantRef, {
        status: "failed",
        error: message,
        failedAt: FieldValue.serverTimestamp(),
      });
      return "failed" as const;
    });
    return finalStatus;
  }
}

export const EARLY_ADOPTER_CAMPAIGN = { collection: CAMPAIGNS, id: CAMPAIGN_ID, limit: CAMPAIGN_LIMIT } as const;

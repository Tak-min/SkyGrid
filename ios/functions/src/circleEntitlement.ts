import {
  FREE_CIRCLE_LIMIT,
  PRO_CIRCLE_LIMIT,
  type CircleLimits,
} from "./invites.js";

export const REVENUECAT_PREMIUM_ENTITLEMENT_ID = "premium";
const REVENUECAT_CUSTOMER_ENDPOINT = "https://api.revenuecat.com/v1/subscribers/";

/**
 * Internal control flow only: a transaction reached the Free boundary and needs
 * authoritative live limits before it can decide. It is never returned to a client.
 */
export class CircleEntitlementRequiredError extends Error {
  constructor(
    readonly inviterUid: string,
    readonly claimerUid: string,
  ) {
    super("Live circle entitlements are required.");
  }
}

export class RevenueCatEntitlementUnavailableError extends Error {}

export type CircleLimitsByUid = Readonly<Record<string, number>>;

export function limitsOrRequireLiveEntitlements(input: {
  inviterUid: string;
  claimerUid: string;
  inviterAcceptedCount: number;
  claimerAcceptedCount: number;
  suppliedLimitsByUid?: CircleLimitsByUid;
  resolveEntitlementIfNeeded?: boolean;
}): CircleLimits {
  if (input.suppliedLimitsByUid) {
    const inviterLimit = input.suppliedLimitsByUid[input.inviterUid];
    const claimerLimit = input.suppliedLimitsByUid[input.claimerUid];
    if (Number.isInteger(inviterLimit) && Number.isInteger(claimerLimit)) {
      return { inviterLimit, claimerLimit };
    }
    // A handle can be reassigned between the first and second transaction. Never
    // apply the old recipient's paid limit to the newly resolved account.
    throw new CircleEntitlementRequiredError(input.inviterUid, input.claimerUid);
  }
  const fitsFree = input.inviterAcceptedCount + 1 <= FREE_CIRCLE_LIMIT
    && input.claimerAcceptedCount + 1 <= FREE_CIRCLE_LIMIT;
  if (fitsFree || !input.resolveEntitlementIfNeeded) {
    return { inviterLimit: FREE_CIRCLE_LIMIT, claimerLimit: FREE_CIRCLE_LIMIT };
  }
  throw new CircleEntitlementRequiredError(input.inviterUid, input.claimerUid);
}

/**
 * Resolves both sides directly from RevenueCat for this operation. The webhook mirror
 * is deliberately not a cache here: a missing purchase webhook would deny a real Pro,
 * while a missing expiration/refund webhook would grant a stale Pro. If RevenueCat is
 * unavailable, callers must leave Firestore unchanged and surface a retryable error.
 */
export async function fetchLiveCircleLimits(input: {
  inviterUid: string;
  claimerUid: string;
  apiKey: string;
  nowMs: number;
  fetchImpl?: typeof fetch;
}): Promise<CircleLimits> {
  const { inviterUid, claimerUid, apiKey, nowMs, fetchImpl = fetch } = input;
  const [inviterLimit, claimerLimit] = await Promise.all([
    fetchLiveCircleLimit({ uid: inviterUid, apiKey, nowMs, fetchImpl }),
    fetchLiveCircleLimit({ uid: claimerUid, apiKey, nowMs, fetchImpl }),
  ]);
  return { inviterLimit, claimerLimit };
}

export async function fetchLiveCircleLimitsByUid(input: {
  inviterUid: string;
  claimerUid: string;
  apiKey: string;
  nowMs: number;
  fetchImpl?: typeof fetch;
}): Promise<CircleLimitsByUid> {
  const limits = await fetchLiveCircleLimits(input);
  return {
    [input.inviterUid]: limits.inviterLimit,
    [input.claimerUid]: limits.claimerLimit,
  };
}

export async function fetchLiveCircleLimit(input: {
  uid: string;
  apiKey: string;
  nowMs: number;
  fetchImpl?: typeof fetch;
}): Promise<number> {
  const { uid, apiKey, nowMs, fetchImpl = fetch } = input;
  if (!apiKey) throw new RevenueCatEntitlementUnavailableError("RevenueCat API key is unavailable.");

  let response: Response;
  try {
    response = await fetchImpl(REVENUECAT_CUSTOMER_ENDPOINT + encodeURIComponent(uid), {
      headers: { Authorization: `Bearer ${apiKey}` },
      signal: AbortSignal.timeout(5_000),
    });
  } catch {
    throw new RevenueCatEntitlementUnavailableError("RevenueCat could not be reached.");
  }
  if (!response.ok) {
    throw new RevenueCatEntitlementUnavailableError(`RevenueCat returned HTTP ${response.status}.`);
  }

  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    throw new RevenueCatEntitlementUnavailableError("RevenueCat returned invalid JSON.");
  }
  return hasActivePremiumEntitlement(payload, nowMs) ? PRO_CIRCLE_LIMIT : FREE_CIRCLE_LIMIT;
}

/** RevenueCat v1 includes expired entitlements, so presence alone never grants Pro. */
export function hasActivePremiumEntitlement(payload: unknown, nowMs: number): boolean {
  if (!payload || typeof payload !== "object") return false;
  const subscriber = (payload as { subscriber?: unknown }).subscriber;
  if (!subscriber || typeof subscriber !== "object") return false;
  const entitlements = (subscriber as { entitlements?: unknown }).entitlements;
  if (!entitlements || typeof entitlements !== "object") return false;
  const entitlement = (entitlements as Record<string, unknown>)[REVENUECAT_PREMIUM_ENTITLEMENT_ID];
  if (!entitlement || typeof entitlement !== "object") return false;

  const record = entitlement as {
    expires_date?: unknown;
    grace_period_expires_date?: unknown;
  };
  if (record.expires_date === null) return true;
  const expirationMs = parsedDateMs(record.expires_date);
  const graceExpirationMs = parsedDateMs(record.grace_period_expires_date);
  return Math.max(expirationMs, graceExpirationMs) > nowMs;
}

function parsedDateMs(value: unknown): number {
  if (typeof value !== "string") return Number.NEGATIVE_INFINITY;
  const milliseconds = Date.parse(value);
  return Number.isFinite(milliseconds) ? milliseconds : Number.NEGATIVE_INFINITY;
}

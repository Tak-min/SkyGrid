/**
 * Admin CLI: retroactively grants the "first 100 users get 60 days free Pro" campaign
 * to existing users, ordered by signup date. Shares its slot-claiming and
 * RevenueCat-granting logic with the live `onPostCreatedClaimEarlyAdopterSlot` Cloud
 * Function trigger (see `../earlyAdopterGrantStore.ts`) — both paths claim slots from
 * the same `campaigns/earlyAdopter100` counter, so they can never collectively exceed
 * 100 grants. See README.md in this directory for full usage.
 *
 * Run via `npm run grant-early-adopter -- <mode>` from `ios/functions/`.
 */
import * as admin from "firebase-admin";
import { FieldValue, type Firestore } from "firebase-admin/firestore";
import {
  claimEarlyAdopterSlot,
  completeGrant,
  EARLY_ADOPTER_CAMPAIGN,
  QA_DENYLIST,
  revokeEntitlement,
} from "../earlyAdopterGrantStore.js";

const FIREBASE_PROJECT_ID = "sky-grid-app";
const FETCH_HEADROOM = 400;
const REVENUECAT_BASE_URL = "https://api.revenuecat.com/v1";

function uidForLog(uid: string): string {
  return `${uid.slice(0, 6)}…`;
}

function requireProductionConfirmation(args: string[]): void {
  const index = args.indexOf("--confirm-project");
  if (index === -1 || args[index + 1] !== FIREBASE_PROJECT_ID) {
    throw new Error(
      `This mode can change production state. Re-run with --confirm-project ${FIREBASE_PROJECT_ID}`,
    );
  }
}

interface UserDoc {
  uid: string;
  handle?: string;
  createdAt?: { toMillis(): number };
}

interface CandidateBreakdown {
  totalFetched: number;
  excludedNoHandle: number;
  excludedNoPosts: number;
  excludedDenylist: number;
  excludedAlreadyHasGrantEntry: number;
  excludedAlreadyPremium: number;
  finalCandidateCount: number;
  remainingSlotsAtStart: number;
  oldestCreatedAt?: number;
  newestCreatedAt?: number;
  sampleUidPrefixes: string[];
}

interface CampaignCounter {
  claimedCount: number;
  limit: number;
  phase: "backfill" | "live" | "closed";
}

async function readCounter(db: Firestore): Promise<CampaignCounter | null> {
  const snap = await db.collection(EARLY_ADOPTER_CAMPAIGN.collection).doc(EARLY_ADOPTER_CAMPAIGN.id).get();
  if (!snap.exists) return null;
  return snap.data() as CampaignCounter;
}

async function provisionCampaign(db: Firestore): Promise<void> {
  const ref = db.collection(EARLY_ADOPTER_CAMPAIGN.collection).doc(EARLY_ADOPTER_CAMPAIGN.id);
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(ref);
    if (existing.exists) {
      throw new Error(`campaigns/${EARLY_ADOPTER_CAMPAIGN.id} already exists; refusing to overwrite it`);
    }
    transaction.create(ref, {
      claimedCount: 0,
      limit: EARLY_ADOPTER_CAMPAIGN.limit,
      phase: "backfill",
      createdAt: FieldValue.serverTimestamp(),
      closedAt: null,
    });
  });
  console.log("Campaign provisioned in backfill phase. Live claims remain paused.");
}

async function activateLiveClaims(db: Firestore): Promise<void> {
  const ref = db.collection(EARLY_ADOPTER_CAMPAIGN.collection).doc(EARLY_ADOPTER_CAMPAIGN.id);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) throw new Error("Campaign is not provisioned");
    const counter = snapshot.data() as CampaignCounter;
    if (counter.phase !== "backfill") {
      throw new Error(`Campaign must be in backfill phase, found ${String(counter.phase)}`);
    }
    if (!Number.isInteger(counter.claimedCount) || !Number.isInteger(counter.limit) ||
        counter.claimedCount < 0 || counter.limit < 1 || counter.limit > EARLY_ADOPTER_CAMPAIGN.limit) {
      throw new Error("Campaign counter is malformed; refusing to activate live claims");
    }
    if (counter.claimedCount >= counter.limit) {
      transaction.update(ref, { phase: "closed", closedAt: FieldValue.serverTimestamp() });
      return;
    }
    transaction.update(ref, { phase: "live", liveActivatedAt: FieldValue.serverTimestamp() });
  });
  console.log("Campaign activation completed. Live claims are enabled only if capacity remains.");
}

/**
 * Selects up to `cap` candidates from the earliest-signed-up users who look eligible.
 * A read-only preview — does NOT claim slots (claiming happens one at a time in
 * `executeGrant`, via the same transactional path the live trigger uses). Because this
 * is read-only, `excludedAlreadyHasGrantEntry` may undercount slightly vs. what
 * `--execute` sees moments later if new grants land concurrently — that's expected and
 * harmless, `claimEarlyAdopterSlot`'s transaction is the actual authority.
 */
async function selectCandidates(
  db: Firestore,
  cap: number,
): Promise<{ candidates: UserDoc[]; breakdown: CandidateBreakdown }> {
  const usersRef = db.collection("users");
  let totalFetched = 0;
  let excludedNoHandle = 0;
  let excludedNoPosts = 0;
  let excludedDenylist = 0;
  let excludedAlreadyHasGrantEntry = 0;
  let excludedAlreadyPremium = 0;
  const candidates: UserDoc[] = [];

  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  while (candidates.length < cap) {
    let query = usersRef.orderBy("createdAt", "asc").limit(FETCH_HEADROOM);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;
    totalFetched += snapshot.docs.length;

    for (const doc of snapshot.docs) {
      if (candidates.length >= cap) break;

      const user = doc.data() as UserDoc;
      const uid = doc.id;
      user.uid = uid;

      if (!user.handle) {
        excludedNoHandle++;
        continue;
      }
      if (QA_DENYLIST.includes(uid)) {
        excludedDenylist++;
        continue;
      }
      const postsSnap = await doc.ref.collection("posts").limit(1).get();
      if (postsSnap.empty) {
        excludedNoPosts++;
        continue;
      }
      const grantSnap = await db.collection("earlyAdopterGrants").doc(uid).get();
      if (grantSnap.exists) {
        excludedAlreadyHasGrantEntry++;
        continue;
      }
      const entitlementSnap = await db.collection("entitlements").doc(uid).get();
      if (entitlementSnap.data()?.isPro === true) {
        excludedAlreadyPremium++;
        continue;
      }

      candidates.push(user);
    }

    cursor = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.docs.length < FETCH_HEADROOM) break;
  }

  const createdAtValues = candidates.map((u) => u.createdAt?.toMillis?.() ?? 0).filter((v) => v > 0);

  const breakdown: CandidateBreakdown = {
    totalFetched,
    excludedNoHandle,
    excludedNoPosts,
    excludedDenylist,
    excludedAlreadyHasGrantEntry,
    excludedAlreadyPremium,
    finalCandidateCount: candidates.length,
    remainingSlotsAtStart: cap,
    oldestCreatedAt: createdAtValues.length ? Math.min(...createdAtValues) : undefined,
    newestCreatedAt: createdAtValues.length ? Math.max(...createdAtValues) : undefined,
    sampleUidPrefixes: candidates.slice(0, 10).map((u) => u.uid.substring(0, 6)).concat(candidates.length > 10 ? ["..."] : []),
  };

  return { candidates, breakdown };
}

async function dryRun(db: Firestore, limitOverride?: number): Promise<void> {
  console.log("Running in DRY-RUN mode (no changes will be made)...\n");
  const counter = await readCounter(db);
  if (!counter) {
    console.error(
      `campaigns/${EARLY_ADOPTER_CAMPAIGN.id} does not exist. Run --provision with explicit project confirmation first.`,
    );
    return;
  }
  const remaining = Math.max(0, counter.limit - counter.claimedCount);
  const cap = limitOverride !== undefined ? Math.min(limitOverride, remaining) : remaining;
  const { breakdown } = await selectCandidates(db, cap);
  console.log(JSON.stringify({ counter, ...breakdown }, null, 2));
}

async function executeGrant(db: Firestore, limitOverride?: number): Promise<void> {
  console.log("Running in EXECUTE mode...\n");

  const counter = await readCounter(db);
  if (!counter) {
    console.error(
      `campaigns/${EARLY_ADOPTER_CAMPAIGN.id} does not exist. Run --provision with explicit project confirmation first.`,
    );
    process.exitCode = 1;
    return;
  }
  const remaining = Math.max(0, counter.limit - counter.claimedCount);
  if (remaining <= 0) {
    console.log("Campaign already exhausted (0 slots remaining). Nothing to do.");
    return;
  }
  const cap = limitOverride !== undefined ? Math.min(limitOverride, remaining) : remaining;

  const { candidates } = await selectCandidates(db, cap);
  console.log(`Attempting to grant to ${candidates.length} users (cap ${cap}, ${remaining} slots remaining)...\n`);

  const runId = `run-${Date.now()}`;
  let grantedCount = 0;
  let failedCount = 0;
  let alreadyCount = 0;
  const failedUids: string[] = [];

  for (const candidate of candidates) {
    const uid = candidate.uid;
    const result = await claimEarlyAdopterSlot(db, uid, { source: "batch", runId });

    if (result === "exhausted") {
      console.log("Campaign exhausted mid-run (a live grant likely claimed the last slot). Stopping.");
      break;
    }
    if (result === "already") {
      console.log(`[${uidForLog(uid)}] Already has a grant entry, skipping.`);
      alreadyCount++;
      continue;
    }

    const outcome = await completeGrant(db, uid);
    if (outcome === "granted") {
      console.log(`[${uidForLog(uid)}] Granted successfully.`);
      grantedCount++;
    } else {
      console.log(`[${uidForLog(uid)}] Grant failed — recorded as status:"failed", slot stays claimed. Use --retry-failed or --reconcile.`);
      failedCount++;
      failedUids.push(uidForLog(uid));
    }
  }

  console.log(
    `\nRun ID: ${runId} (use with --revoke-run to revoke this batch specifically)`,
  );
  console.log(
    `Summary: ${grantedCount} granted, ${failedCount} failed, ${alreadyCount} already had an entry, out of ${candidates.length} attempted.`,
  );
  if (failedUids.length > 0) {
    console.log(`Failed UIDs (retry with --retry-failed, or --reconcile to check actual RevenueCat state): ${failedUids.join(", ")}`);
  }
}

/** Re-attempts the RevenueCat grant call for every `status:"failed"` doc. Does not re-claim a slot — it's already claimed. */
async function retryFailed(db: Firestore): Promise<void> {
  const snapshot = await db.collection("earlyAdopterGrants").where("status", "==", "failed").get();
  console.log(`Found ${snapshot.docs.length} failed grants to retry.\n`);

  let grantedCount = 0;
  let stillFailedCount = 0;
  for (const doc of snapshot.docs) {
    const uid = doc.id;
    const state = await revenueCatPremiumState(uid);
    if (state.kind === "unknown") {
      console.log(`[${uidForLog(uid)}] RevenueCat state could not be confirmed; not retrying.`);
      stillFailedCount++;
      continue;
    }
    if (state.kind === "active") {
      await doc.ref.update({
        status: "granted",
        grantedAt: FieldValue.serverTimestamp(),
        expiresAtMs: state.expiresAtMs,
        reconciledAt: FieldValue.serverTimestamp(),
      });
      console.log(`[${uidForLog(uid)}] Already active on RevenueCat; reconciled without another grant call.`);
      grantedCount++;
      continue;
    }
    if (!Number.isFinite(doc.data().plannedExpiresAtMs)) {
      console.log(`[${uidForLog(uid)}] Missing planned expiry; manual review required, not retrying.`);
      stillFailedCount++;
      continue;
    }
    const outcome = await completeGrant(db, uid);
    if (outcome === "granted") {
      console.log(`[${uidForLog(uid)}] Retry succeeded after RevenueCat confirmed inactive.`);
      grantedCount++;
    } else {
      console.log(`[${uidForLog(uid)}] Retry failed again.`);
      stillFailedCount++;
    }
  }
  console.log(`\nSummary: ${grantedCount} granted on retry, ${stillFailedCount} still failed.`);
}

/**
 * For every `status:"failed"` doc, checks RevenueCat's actual subscriber state — the
 * RevenueCat call may have actually succeeded even though the doc was marked failed
 * (e.g. a response timeout after the grant went through). If the `premium` entitlement
 * is genuinely active, marks the doc `granted` retroactively. Never auto-releases a
 * slot back to the counter either way — a human decides what to do with a doc that
 * stays `failed` after reconciliation.
 */
type RevenueCatPremiumState =
  | { kind: "active"; expiresAtMs: number | null }
  | { kind: "inactive" }
  | { kind: "unknown" };

async function revenueCatPremiumState(uid: string): Promise<RevenueCatPremiumState> {
  const secretKey = process.env.REVENUECAT_SECRET_API_KEY;
  if (!secretKey) {
    throw new Error("REVENUECAT_SECRET_API_KEY environment variable not set");
  }

  const response = await fetch(`${REVENUECAT_BASE_URL}/subscribers/${encodeURIComponent(uid)}`, {
    headers: { Authorization: `Bearer ${secretKey}` },
  });
  if (response.status !== 200) return { kind: "unknown" };
  let data: { subscriber?: { entitlements?: { premium?: { expires_date?: string | null } } } };
  try {
    data = await response.json() as typeof data;
  } catch {
    return { kind: "unknown" };
  }
  const entitlement = data.subscriber?.entitlements?.premium;
  if (!entitlement) return { kind: "inactive" };
  const expiresAtMs = entitlement.expires_date ? new Date(entitlement.expires_date).getTime() : null;
  if (expiresAtMs !== null && !Number.isFinite(expiresAtMs)) return { kind: "unknown" };
  return expiresAtMs === null || expiresAtMs > Date.now()
    ? { kind: "active", expiresAtMs }
    : { kind: "inactive" };
}

async function reconcile(db: Firestore): Promise<void> {
  if (!process.env.REVENUECAT_SECRET_API_KEY) {
    console.error("REVENUECAT_SECRET_API_KEY environment variable not set");
    process.exitCode = 1;
    return;
  }

  const snapshot = await db.collection("earlyAdopterGrants").where("status", "==", "failed").get();
  console.log(`Reconciling ${snapshot.docs.length} failed grants against RevenueCat...\n`);

  let reconciledCount = 0;
  let stillFailedCount = 0;
  for (const doc of snapshot.docs) {
    const uid = doc.id;
    const state = await revenueCatPremiumState(uid);
    if (state.kind === "unknown") {
      console.log(`[${uidForLog(uid)}] Could not confirm RevenueCat state; leaving as failed.`);
      stillFailedCount++;
      continue;
    }
    if (state.kind === "active") {
      await doc.ref.update({
        status: "granted",
        grantedAt: FieldValue.serverTimestamp(),
        expiresAtMs: state.expiresAtMs,
        reconciledAt: FieldValue.serverTimestamp(),
      });
      console.log(`[${uidForLog(uid)}] Active on RevenueCat — reconciled to granted.`);
      reconciledCount++;
    } else {
      console.log(`[${uidForLog(uid)}] Confirmed inactive on RevenueCat; leaving as failed.`);
      stillFailedCount++;
    }
  }
  console.log(`\nSummary: ${reconciledCount} reconciled to granted, ${stillFailedCount} confirmed still failed.`);
}

async function revokeSingleUid(db: Firestore, uid: string): Promise<void> {
  console.log(`Revoking entitlement for ${uidForLog(uid)}...\n`);
  const grantRef = db.collection("earlyAdopterGrants").doc(uid);
  const grantSnap = await grantRef.get();
  if (!grantSnap.exists) {
    console.error(`[${uidForLog(uid)}] No earlyAdopterGrants entry found; nothing to revoke.`);
    process.exitCode = 1;
    return;
  }

  try {
    await revokeEntitlement(uid);
    await grantRef.update({ status: "revoked", revokedAt: FieldValue.serverTimestamp() });
    console.log(`[${uidForLog(uid)}] Revoked successfully.`);
  } catch (error) {
    console.error(`[${uidForLog(uid)}] Revoke failed: ${error instanceof Error ? error.message : error}`);
    process.exitCode = 1;
  }
}

async function revokeByRunId(db: Firestore, runId: string): Promise<void> {
  console.log(`Revoking all entitlements for run "${runId}"...\n`);
  const snapshot = await db
    .collection("earlyAdopterGrants")
    .where("runId", "==", runId)
    .where("status", "==", "granted")
    .get();
  console.log(`Found ${snapshot.docs.length} granted entries for this run.\n`);

  let revokedCount = 0;
  let failedCount = 0;
  const failedUids: string[] = [];
  for (const doc of snapshot.docs) {
    const uid = doc.id;
    try {
      await revokeEntitlement(uid);
      await doc.ref.update({ status: "revoked", revokedAt: FieldValue.serverTimestamp() });
      console.log(`[${uidForLog(uid)}] Revoked successfully.`);
      revokedCount++;
    } catch (error) {
      console.log(`[${uidForLog(uid)}] Revoke failed: ${error instanceof Error ? error.message : error}`);
      failedCount++;
      failedUids.push(uidForLog(uid));
    }
  }
  console.log(`\nSummary: ${revokedCount} revoked, ${failedCount} failed.`);
  if (failedUids.length > 0) console.log(`Failed UIDs: ${failedUids.join(", ")}`);
}

function parseLimit(args: string[]): number | undefined {
  const idx = args.indexOf("--limit");
  if (idx === -1) return undefined;
  const value = Number(args[idx + 1]);
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error("--limit requires a positive integer");
  }
  return Math.floor(value);
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const mode = args[0];

  try {
    const mutatingModes = new Set([
      "--provision", "--activate-live", "--execute", "--retry-failed", "--reconcile", "--revoke", "--revoke-run",
    ]);
    if (mode && mutatingModes.has(mode)) requireProductionConfirmation(args);
    if (mode === "--execute" && QA_DENYLIST.length === 0 && !args.includes("--allow-empty-qa-denylist")) {
      throw new Error(
        "QA_DENYLIST is empty. Populate it, or explicitly pass --allow-empty-qa-denylist after reviewing the dry-run.",
      );
    }

    admin.initializeApp({ projectId: FIREBASE_PROJECT_ID });
    const db = admin.firestore();

    if (mode === "--provision") {
      await provisionCampaign(db);
    } else if (mode === "--activate-live") {
      await activateLiveClaims(db);
    } else if (mode === "--execute") {
      await executeGrant(db, parseLimit(args));
    } else if (mode === "--retry-failed") {
      await retryFailed(db);
    } else if (mode === "--reconcile") {
      await reconcile(db);
    } else if (mode === "--revoke") {
      const uid = args[1];
      if (!uid) {
        console.error("Usage: --revoke <uid>");
        process.exitCode = 1;
        return;
      }
      await revokeSingleUid(db, uid);
    } else if (mode === "--revoke-run") {
      const runId = args[1];
      if (!runId) {
        console.error("Usage: --revoke-run <runId>");
        process.exitCode = 1;
        return;
      }
      await revokeByRunId(db, runId);
    } else if (mode === "--dry-run" || mode === undefined || mode === "") {
      await dryRun(db, parseLimit(args));
    } else {
      console.error(
        `Unknown mode: ${mode}. Supported: --provision, --dry-run (default) [--limit N], --execute [--limit N], --activate-live, --retry-failed, --reconcile, --revoke <uid>, --revoke-run <runId>`,
      );
      process.exitCode = 1;
    }
  } catch (error) {
    console.error(`Fatal error: ${error instanceof Error ? error.message : error}`);
    process.exitCode = 1;
  }
}

main();

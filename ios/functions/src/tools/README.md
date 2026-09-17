# Early Adopter Grant Script

Grants a free 60-day RevenueCat "premium" promotional entitlement to the first 100 users
of the SkyGrid app — combining a one-off retroactive batch over existing users (this CLI)
with an always-on live trigger for new signups (`onPostCreatedClaimEarlyAdopterSlot` in
`../index.ts`, fires on each user's first successful photo capture). Both paths claim
slots from the same `campaigns/earlyAdopter100` Firestore counter via
`../earlyAdopterGrantStore.ts`'s `claimEarlyAdopterSlot`, so together they can never
exceed 100 total grants.

## Prerequisites

1. **Firebase Authentication**:
   ```bash
   gcloud auth application-default login
   # OR
   firebase login
   ```

2. **RevenueCat API Key**:
   ```bash
   export REVENUECAT_SECRET_API_KEY=<your-secret-key>
   ```
   **WARNING**: Never commit or log this key.

3. **The campaign counter must exist in Firestore before `--execute` (or the live
   trigger) can claim anything**: create `campaigns/earlyAdopter100` with
   `{ claimedCount: 0, limit: 100, closedAt: null }`. `--dry-run` and `--execute` both
   fail loudly (not silently) if it's missing.

4. Build once before running (the CLI runs from `lib/`, not `src/`):
   ```bash
   npm run build
   ```

## Usage

All commands run from `ios/functions/`.

### Dry-Run Mode (Default)
```bash
npm run grant-early-adopter
# OR
npm run grant-early-adopter -- --dry-run
npm run grant-early-adopter -- --dry-run --limit 5
```
Prints a JSON summary (candidate counts by exclusion reason, remaining slots, no PII
beyond 6-char uid prefixes) without making any changes.

### Execute Mode
```bash
npm run grant-early-adopter -- --execute
npm run grant-early-adopter -- --execute --limit 2   # test against a small batch first
```
For each candidate (earliest-signed-up users first, capped by however many slots
remain): atomically claims a slot, calls RevenueCat, and records `granted` or `failed`.
Stops early if the campaign becomes exhausted mid-run (e.g. the live trigger claimed the
last slot concurrently). Continues past per-uid failures.

**Before running `--execute` for real**: fill in `QA_DENYLIST` in
`../earlyAdopterGrantStore.ts` with known developer/QA uids — an empty denylist prints a
loud warning but does not block the run. Run `--dry-run` first and sanity-check the
summary. Then run `--execute --limit 2` and manually verify in the RevenueCat dashboard
(and ideally on a real device) that the entitlement actually reflects as Pro before
running the full batch.

### Retry / Reconcile Failed Grants
A `status:"failed"` doc keeps its slot reserved forever — nothing auto-releases it, since
an automatic release risks a double-grant if the RevenueCat call actually succeeded
despite being recorded as failed (e.g. a response timeout).

```bash
npm run grant-early-adopter -- --retry-failed   # re-attempts the RevenueCat call
npm run grant-early-adopter -- --reconcile      # checks RevenueCat's actual state; marks
                                                  # granted retroactively if it turns out
                                                  # to already be active, else leaves failed
```

### Revoke
```bash
npm run grant-early-adopter -- --revoke <uid>
npm run grant-early-adopter -- --revoke-run <runId>   # printed at the end of an --execute run
```

## Database Schema

`earlyAdopterGrants/{uid}`:
- `uid`, `source` (`"batch"` or `"live"`), `runId` (batch runs only), `status`
  (`pending`/`granted`/`failed`/`revoked`), `entitlement` (always `"premium"`),
  `createdAt`, `grantedAt`, `expiresAtMs`, `error`, `failedAt`, `revokedAt`,
  `reconciledAt` (set only by `--reconcile`).

`campaigns/earlyAdopter100`:
- `claimedCount` (pending + granted + failed, NOT just granted — see
  `earlyAdopterGrantStore.ts`), `limit` (100), `closedAt`.

## Notes

- RevenueCat call sends `end_time_ms` only, never `duration` — confirmed against the
  RevenueCat dashboard's own "Grant entitlement" UI, which has no 60-day duration preset
  and treats duration-preset vs. "Until date" as mutually exclusive modes.
- This CLI shares all grant/claim logic with the live Cloud Function trigger; there is
  exactly one implementation of the atomic slot-claim and the RevenueCat-call contract.

# Claude Code design handoff — 2026-09-04

## Roles and scope

The product owner has selected the following directions and requests that Claude Code make the
remaining detailed design decisions. Codex will implement only after Claude produces an
implementation-ready decision record. Do not deploy, push, modify Firebase Console, App Store
Connect, or production data.

Owner choices:

1. **1A — hard N-way circle cap:** enforce a maximum of 8 buddies on every creation route.
2. **2B — Buddies relationship destination:** each Buddy row needs a relationship-detail
   destination.
3. **3B — buddy streak:** calculate and expose a buddy streak server-side.
4. **4A — onboarding:** keep pace/frequency while telemetry is collected; assess after 14 days
   and 100 onboarding starts, using the stated abandonment/relevance condition.
5. **5C — multi-alarm:** support arbitrary repeating weekdays and times.
6. **6C — motion gate:** make a motion condition mandatory.

These are decisions already made by the owner. The task here is to resolve their concrete product,
privacy, failure-mode, data-model, and release semantics before implementation. Do not silently
replace an owner choice with a lower-scope alternative.

## Observed implementation facts

- Friendship is pairwise: `friendships/{pairId}` is a protected document shape. Preserve it;
  "N-way" means multiple independent buddy edges, not a shared group visibility model.
- Link claims already run through `ios/functions/src/invites.ts` / `inviteStore.ts` and have
  `MAX_ACCEPTED_BUDDIES = 8`. Handle request/accept in
  `ios/SkyGrid/Sources/Data/Firebase/FirebaseFriendRepository.swift` are still direct Firestore
  writes that bypass that cap under the current `ios/firestore.rules`.
- `blockedBy` must always be populated in any server-written friendship document or existing buddy
  reads fail under the Firestore rules. See project `AGENTS.md`.
- Current `UserProfile.streakCurrent` is not server-maintained (effectively zero). The app derives
  the current user's streak locally from that user's posts. Buddy historical posts are privacy
  gated by mutual reveal, so a streak is a new disclosure decision, not a display-only change.
- AlarmKit's OS Stop action occurs before app code runs. A motion gate cannot prevent OS-level
  dismissal. It can only be a mandatory in-app condition before the next ritual step; the exact
  flow, permission behavior, offline behavior, timeout/accessibility escape hatch, and anti-bypass
  promise must be explicit.
- The scheduler currently supports a single daily time and one alarm identifier in
  `MorningAlarmScheduler.swift`. Arbitrary schedules require a durable schedule model, migration
  from the existing single `wakeGoalMinutes`, multiple identifiers, updates/deletions, notification
  fallback parity for iOS 17–25, and timezone/DST behavior.
- Onboarding telemetry is now emitted without PII in `OnboardingAnalytics.swift`. Event arrival in
  Firebase remains unverified, so no deletion decision should be derived yet.
- D7 mutual reveal is the north-star metric, currently unmeasured. `PRODUCT-MODEL.md` is the
  current source of truth.

## Required Claude deliverable

Write an implementation handoff in `dev-notes/` (or update this file) with, for each numbered
choice:

1. user-facing flow and precise copy/state semantics;
2. privacy, safety, consent, and accessibility rules;
3. persisted schema and migration/rollback semantics;
4. client/server ownership, including Firestore Rules and callable contracts where applicable;
5. failure and offline behavior;
6. acceptance criteria and focused test matrix;
7. dependency order and which pieces must be feature-flagged or separately deployed.

Resolve cross-feature conflicts explicitly: multi-alarm/motion gate must not falsely imply that
the OS alarm remains sounding; streak disclosure must remain compatible with mutual-reveal privacy;
the hard cap must not leave a direct client bypass; relationship detail must not expose posts that
the current relationship cannot read.

If an owner selection admits multiple materially different safe meanings, ask the owner a concise,
specific question rather than inventing one. Otherwise commit the decision record only; do not
implement application code in this Claude pass, because Codex owns implementation and validation.

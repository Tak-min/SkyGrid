# Owner-selected 3B / 5C / 6C — implementation decision record (2026-09-05)

## Scope and roles

Per `.loop/CLAUDE-DESIGN-HANDOFF-2026-09-04.md`, the owner has already selected the direction
for three remaining features. This record resolves their concrete product, privacy,
failure-mode, data-model, and release semantics so Codex can implement without re-deriving
design decisions. **No application code is changed or deployed in this pass.**

- **3B** — calculate and expose a buddy streak server-side.
- **5C** — support arbitrary repeating weekdays and times for the morning alarm.
- **6C** — make the morning ritual's "wake condition" mandatory, not optional.

6C's concrete mechanism was renegotiated with the owner during this design pass (see
`§3 — 6C` below) and no longer matches the CoreMotion-gate framing in the handoff doc's
observed-facts section. That framing was the handoff author's best guess at the owner's
intent, not the owner's own words; once clarified directly with the owner, this record
implements the owner's actual intent rather than the guess, and documents why the
originally-suggested mechanism was rejected.

---

## §1 — 3B: server-side buddy streak

### 1.1 Definition — pair-level, not personal

**A buddy streak is a pair-level streak**: the number of consecutive local dates on which
*both* members of `friendships/{pairId}` have a post document. It is a new, separate value
from the existing personal streak that `TodayViewModel` derives client-side from the
viewer's own posts (`ios/SkyGrid/Sources/Streak/StreakWindow.swift`). It does not replace
`UserProfile.streakCurrent`/`streakLongest`, which stay permanently `0` and undisplayed —
nothing in production writes them today, and this change does not start.

**Why pair-level and not "show me my buddy's personal streak"**: the pair definition is
the only one that is a mathematical no-op against the mutual-reveal privacy boundary
(`ios/firestore.rules` — `posts/{localDate}` `get`/`list` requires `activeBuddy(uid) &&
hasPostedFor(localDate)`, i.e. the viewer must have posted that same date). A pair streak
can only change on a day the viewer themselves posted, so every increment the viewer
observes is on a day already unlocked for them — the streak discloses nothing they could
not already read directly from the buddy's post. Exposing the buddy's *personal* streak
would leak "buddy posted on day D" for days the viewer never unlocked — a direct
side-channel around the reveal rule. Rejected for the same reason: any "streak freeze"
that can survive a day the *viewer* missed, since a value that moves on a day the viewer
didn't post is exactly the side-channel being avoided. (An asymmetric freeze that only
survives the *buddy's* miss on a day the viewer posted would be safe but is out of scope
for v1.)

### 1.2 User-facing flow and copy

Displayed on the buddy row / relationship destination (2B) and the buddy tile on Today,
computed client-side from the friendship document plus the viewer's own local date:

| condition | render |
|---|---|
| `streakLastMutualDate == today` or `== yesterday` | `Together 12 days` (or `Together 1 day` at 1) |
| otherwise (stale or absent) | nothing |

Deliberately never rendered: "streak broken," any countdown, any comparison between
members, any attribution of a miss ("Ren missed yesterday" is a disclosure on a day the
viewer hasn't posted and is prohibited). Silence on a stale value is the correct default —
it degrades gracefully with zero extra logic.

Accessibility: `accessibilityLabel` spells out the relationship ("Twelve consecutive
mornings with Ren"), not just the digit.

**No streak-risk push notification in v1** (owner-confirmed, Q5). A "your streak with Ren
ends today" push is technically privacy-safe (it can only be evaluated on a day the viewer
already posted) but is the shortest path from a gentle ritual to a guilt engine, and needs
its own consent/quiet-hours decision (`buddyNotifications.ts:89-114`) that is out of scope
here.

### 1.3 Persisted schema and migration

Three additive, server-owned fields on the existing `friendships/{pairId}` document — no
new collection (a subcollection would need its own Rules block and a second read for a
screen that already reads the friendship doc):

| field | type | meaning |
|---|---|---|
| `streakCurrent` | int | consecutive mutual local dates ending at `streakLastMutualDate` |
| `streakLongest` | int | max `streakCurrent` ever observed for this pair |
| `streakLastMutualDate` | string `YYYY-MM-DD` \| absent | most recent date both members posted |
| `streakTrackingSince` | server timestamp \| absent | set on the first streak write for this pair |

**Migration (owner-confirmed, Q1): cold-start at 0 for every existing pair. No backfill.**
`streakTrackingSince` exists precisely so the client can render "counting since ⟨date⟩"
instead of an unexplained 0 for a pair that has actually posted together for months —
this is the cheap mitigation for the cost of not backfilling, not a placeholder for a
future backfill.

**Rollback**: delete the trigger function (§1.4). The three fields go stale but are inert —
no Rules depend on them, and the display rule in §1.2 makes a stale value disappear from
the UI within 48h with no extra code. Ship the client change behind
`FeatureFlags.buddyStreakVisible` so the fields can be written for a release cycle before
anything renders, giving a real rollback window even after client release.

### 1.4 Client/server ownership — Firestore Rules and callable/trigger contract

**No Rules change required.** `ios/firestore.rules`'s existing `friendships/{pairId}`
update rule restricts client writes to `diff(resource.data).affectedKeys().hasOnly(['blockedBy'])`.
Any new field is therefore already unwritable by a client and already readable by both
members via the existing `allow get, list`. This makes 3B a functions-only backend change.

**Server owns 100% of the write.** New exported function in `ios/functions/src/index.ts`:

```
onPostCreatedUpdateBuddyStreaks
  document: "users/{uid}/posts/{localDate}"
  region: "asia-northeast1"   // must match Firestore's region, same reason as
                                // the existing onBuddyPostCreated trigger
  retry: true                  // safe: the update is idempotent by construction (below)
```

A **separate** trigger from the existing `onBuddyPostCreated` (which fans out push
notifications), not an extension of it — that one is deliberately `retry: false` because a
re-send is worse than a miss; this one is naturally idempotent and should retry. Mixing
the two would force one retry policy onto two opposite failure preferences.

Structure follows the existing `invites.ts`/`inviteStore.ts` split: pure logic in a
framework-free `ios/functions/src/buddyStreaks.ts`, Firestore I/O in
`ios/functions/src/buddyStreakStore.ts`.

Pure function, exhaustively unit-testable with no Firebase dependency:

```
advanceStreak(previous: {current, longest, lastMutualDate}, mutualDate: string)
  -> {current, longest, lastMutualDate}
```

Four branches:
- `mutualDate === lastMutualDate` → **unchanged** (makes retry / redelivery / a
  delete-then-recapture on the same day a true no-op)
- `mutualDate === dayAfter(lastMutualDate)` → `current += 1`, `longest = max(longest, current)`
- `mutualDate > dayAfter(lastMutualDate)` or `lastMutualDate` absent → `current = 1`
- `mutualDate < lastMutualDate` → **unchanged** (a late/backdated post never rewrites
  history — the rules already allow up to 2 days of future-dating, so out-of-order arrival
  is a real case)

Store layer, per post-create event for poster `A` on date `D`:
1. Query `friendships` `where("members", "array-contains", A)` (same query shape the
   existing notification fan-out already uses — no new index).
2. For each doc: skip unless `status === "accepted"` **and** `blockedBy.length === 0`. This
   is the stop condition for a blocked or pending pair.
3. Read `users/{B}/posts/{D}`. If absent, skip — not mutual yet; `B`'s own post-create event
   does the work when it arrives.
4. In a transaction: re-read the friendship doc, re-check accepted/unblocked, apply
   `advanceStreak`, write with `transaction.update()` carrying **only the streak keys** —
   never `set()`.

`update()` on an existing document cannot remove `blockedBy`, so this cannot violate the
AGENTS.md invariant ("a friendship doc written without `blockedBy` makes `activeBuddy()`
error and silently breaks buddy reads for the *other* member"). This must be an explicit
emulator-test assertion, not just a code-review note, given the AGENTS.md rule exists
because that failure is silent and lands on the member who didn't touch the change.

**Delete semantics**: `posts/{localDate}` allows owner delete. A delete of an
already-counted mutual day leaves the streak optimistically high. Accepted, not repaired in
v1 — a decrement would require a full recompute (a run can't be decremented from one
endpoint), and the only production delete path (OrphanedPostRecovery's same-day
delete-then-recapture) is already absorbed as a no-op by the `mutualDate === lastMutualDate`
branch.

**No scheduled function.** A nightly "break the streak" job was considered and rejected —
cost proportional to every pair, every night, and unnecessary because staleness is fully
decidable client-side from `streakLastMutualDate` alone (§1.2).

### 1.5 Failure and offline behavior

- Trigger failure → no write; the next mutual day recovers correctly (fresh 1, or a correct
  increment if only one day was missed at the boundary). Under-counting is the correct
  failure direction for a privacy-adjacent field.
- The function must never throw out of the handler: `try/catch` + `logger.error` safety
  net, matching the existing trigger's pattern.
- Client offline: friendship doc comes from the Firestore cache; a stale
  `streakLastMutualDate` naturally falls outside the render window (§1.2). No offline write
  path exists, so nothing can conflict.

### 1.6 Acceptance criteria and test matrix

Pure tests (`ios/functions/test/buddyStreaks.test.js`):
- all four `advanceStreak` branches, including month/year rollover for `dayAfter`
- idempotency: applying the same `mutualDate` twice yields an identical object
- `longest` only ever increases, never decreases on a reset to 1

Emulator tests (`ios/functions/test/emulator/buddyStreakStore.test.js`):
- A posts, B has not → no write to the friendship doc at all
- B then posts same day → `streakCurrent: 1`, `streakLastMutualDate: D`
- both post D+1 → `2`; both post D+3 → `1`
- pending pair → never written
- `blockedBy: [uid]` pair → never written; unblock then mutual post → resets to 1
- after a streak write, the friendship doc still satisfies `activeBuddy()`'s shape
  (`blockedBy` present) — the AGENTS.md invariant, asserted explicitly
- concurrent A-posts and B-posts for the same `D` → exactly one increment (transaction)

Rules tests (`ios/rules-tests/test.js`), two additions:
- a member cannot write `streakCurrent`/`streakLongest`/`streakLastMutualDate` on their own
  friendship (already denied by the existing `hasOnly(['blockedBy'])`)
- a member can still block/unblock on a document that already carries streak fields (proves
  the additive fields don't break the existing diff-based update rule)

iOS: a pure display-policy test for the today/yesterday/stale window, including a timezone
change between write and render.

### 1.7 Dependency order and flags

1. Deploy **functions only** (`onPostCreatedUpdateBuddyStreaks`). Harmless to every shipped
   client — it writes fields nobody reads yet, satisfying the "a deployed function must be
   harmless to the already-shipped client" rule from the 1A precedent.
2. Add the two new Rules-emulator assertions (no Rules deploy needed — nothing changed).
3. Ship the client behind `FeatureFlags.buddyStreakVisible`.

No dependency on 1A beyond composition: 1A's `requestBuddy`/`acceptBuddy` already write
`blockedBy: []`; the streak trigger only ever `update()`s existing documents.

**Metric framing**: a direct claim on retention of *existing* pairs. A **bet** — not a
claim — that it moves D7 mutual reveal, since a pair streak only becomes visible after the
first mutual day, i.e. after the D7 event has already happened. Instrumentation for this
bet is out of scope here; see `PRODUCT-MODEL.md` before treating it as validated.

---

## §2 — 5C: arbitrary repeating weekday/time alarms, with a re-alarm loop

### 2.1 What changed from the handoff brief

The handoff brief scoped 5C as "support arbitrary repeating weekdays and times" and scoped
6C separately as a motion condition. During owner clarification, the owner's actual intent
for the "wake condition" turned out to be: **the morning should not be over until a photo
is captured** — not a physical-motion sensor check. Realizing "the alarm keeps sounding
until you capture" is impossible on AlarmKit (§3.1) led to a re-scoped mechanism — a
bounded re-alarm loop — that the owner then explicitly approved as part of 5C. This section
covers both the weekday/time model and the re-alarm loop together, since they share the
same scheduler and identifier space.

### 2.2 Data model

New `MorningAlarmSchedule` value type
(`ios/SkyGrid/Sources/Notifications/MorningAlarmSchedule.swift`), `Codable`, `Sendable`:

```swift
struct MorningAlarmSchedule: Codable, Sendable, Identifiable {
    let id: UUID                    // stable; also the AlarmKit alarm identifier
    var minutesAfterMidnight: Int   // 0..<1440, wall clock
    var weekdays: Set<Int>          // 1...7, Gregorian (1 = Sunday), non-empty
    var isEnabled: Bool
}
```

Persisted as a JSON array under a new `LocalDefaults` key `morningAlarmSchedules`, plus a
`morningAlarmScheduleModelVersion: Int` migration marker.

**Persistence scope (owner-confirmed, Q2): device-local only, matching current behavior.**
No sync to `users/{uid}` — that would require extending `firestore.rules`'s
`validProfileKeys()` and the profile update allowlist, plus a multi-device conflict policy
the app has no precedent for. A reinstall or new device loses every alarm silently, exactly
as the single alarm does today.

**`wakeGoalMinutes` survives unchanged** as the "morning goal" — it anchors the per-post
`minutesFromGoal`, the Live Activity window, and the follow-up nudge, and is a
Rules-constrained server profile field. It becomes *derived*: whenever the schedule set
changes, `wakeGoalMinutes = min(minutesAfterMidnight)` over enabled entries; if none are
enabled, leave the last value untouched. This keeps `minutesFromGoal` single-valued and
comparable across days.

**Cap: 5 alarms.** Arithmetic, not taste: iOS's pending-notification limit is 64. The
pre-AlarmKit reminder fallback needs one `UNCalendarNotificationTrigger` per
(alarm × selected weekday) = up to 35 at the cap, plus the follow-up scheduler's 7-day
window = 42, plus the re-alarm loop's transient reservations (§2.5) = comfortable headroom.
A 7-alarm cap would leave almost none, and a silently-dropped request is invisible to the
user.

### 2.3 Migration — must not silently disable an existing alarm

Run once, keyed on `morningAlarmScheduleModelVersion == 0`, from `resyncIfNeeded()` and the
settings screen's load:

1. If `morningAlarmEnabled == true`: synthesize exactly one schedule —
   `id = MorningAlarmScheduler.alarmIdentifier` (the existing fixed UUID constant),
   `minutesAfterMidnight = wakeGoalMinutes`, `weekdays = all 7`, `isEnabled = true`. Reusing
   the *same UUID* is the whole trick — the subsequent `AlarmManager.schedule(id:configuration:)`
   replaces the live OS alarm in place. **Never `cancel(id:)` the legacy identifier during
   migration.**
2. If `morningAlarmEnabled == false`: write an empty array.
3. Set `morningAlarmScheduleModelVersion = 1`.
4. Only *after* the new reminder requests are added, remove the legacy pending
   pre-AlarmKit request, so the fallback path never has a window with zero pending alarms.

**Rollback**: an older build reading a migrated device still finds `wakeGoalMinutes` and
`morningAlarmEnabled` intact and re-arms the legacy single alarm under the same UUID. Data
loss is limited to the extra alarms, which the older build cannot express anyway — this is
why the legacy keys must not be deleted by the migration.

### 2.4 Scheduler rework

`MorningAlarmScheduler` moves to a reconcile-the-set model:

- `enable(schedules:)`/`enableReminderFallback(schedules:)` replace the flat
  `wakeGoalMinutes:` entry points.
- **AlarmKit**: one alarm per schedule entry, `id = entry.id`,
  `Alarm.Schedule.relative(.init(time:, repeats: .weekly(entry.weekdays)))` — AlarmKit's
  `.weekly` already accepts a weekday set, so one entry maps to one OS alarm regardless of
  how many weekdays it covers.
- **`resyncIfNeeded()`** becomes a true reconcile, schedule-first: `schedule()` every
  enabled entry, *then* enumerate `AlarmManager.shared.alarms` and `cancel(id:)` anything not
  in the persisted enabled set (plus anything not in the re-alarm reserved space, §2.5).
  Schedule-first means there is never an instant where the alarm set is empty.
- **Reminder fallback (pre-AlarmKit iOS)**: N×weekday `UNCalendarNotificationTrigger`s.
  Identifier scheme `"com.takmin.skygrid.morning-reminder.<uuid>.<weekday>"`, with the
  existing bare identifier kept as a documented prefix.
- **`NotificationRouter`'s exact-identifier match must become a prefix match.** Without
  this, every fallback alarm on pre-AlarmKit iOS stops opening the camera — this is the
  single highest-risk line in 5C.
- **`disableImmediately()`** cancels every AlarmKit id in the persisted set (not just the
  legacy constant), every prefixed pending reminder request, and any live re-alarm
  reservation (§2.5).

### 2.5 Re-alarm loop — bounded, honest, and non-bricking

**Mechanism** (owner-confirmed, Q4): AlarmKit silences the OS alarm the instant Stop is
tapped — this happens before any app code runs and cannot be prevented (see §3.1 for the
verified platform constraint). What *is* achievable, and what the owner confirmed matches
their intent, is: **after Stop, if no photo has been captured, schedule a single-shot
follow-up alarm 5 minutes later; repeat up to 3 times total; cancel immediately on capture;
stop unconditionally at local-date rollover.**

Implementation point: `MorningAlarmStoppedIntent.perform()` (which already runs in the
background after Stop to start the "sky not captured yet" Live Activity) additionally
schedules the next re-alarm attempt, incrementing an attempt counter persisted alongside the
schedule state.

| parameter | value | rationale |
|---|---|---|
| interval | **5 minutes** (owner-specified) | |
| max attempts | **3** | an unbounded loop is a real "my phone won't stop alarming" complaint risk; 3 attempts × 5 minutes = 15 minutes of total grace, matching a typical snooze budget |
| after max attempts | hand off silently to the existing `MorningFollowUpScheduler` quiet notification | no further alarm; the day's ritual ends the same way it does today for a no-capture morning |
| hard stop condition | current `localDate` has rolled over | unconditional, checked before scheduling each subsequent attempt — a previous day's alarm firing into the next morning is not acceptable under any circumstance |
| cancel condition | `MorningRitualCoordinator.captureCompleted(localDate:)` fires | this is already the single facility that coordinates "photo captured" cleanup (it already ends the Live Activity and cancels the follow-up notification) — the re-alarm cancellation belongs in this same call, not a new one |
| identifier space | a reserved prefix distinct from both the 5-schedule UUID space and the pre-AlarmKit reminder space | so `resyncIfNeeded()`'s reconcile (§2.4) does not mistake a live re-alarm reservation for an orphaned schedule and cancel it |

**Platform parity — explicitly not equal**: pre-AlarmKit iOS (17–25) has no equivalent to a
re-firing system alarm; a local notification is not an alarm and may not sound depending on
system state. The record must say **"a local notification, not an equivalent alarm"** for
this path — never "same experience" — this is a real capability gap, not a copy choice.

### 2.6 Copy constraints (hard rule, cross-checked against 6C's original framing)

**Prohibited, because it would be false**: "the alarm won't stop until you capture," "keeps
ringing," "snooze-proof," any phrasing implying continuous OS-level sound. AlarmKit
confirms the alarm is silenced by the OS the instant Stop is tapped; app code has no
opportunity to prevent that.

**Approved framing**, to be placed in alarm settings and in first-run alarm setup copy:

> **Stop doesn't end your morning.**
> If you don't capture the sky, Sky Grid brings the alarm back every 5 minutes, up to 3
> times. iPhone always silences the alarm the moment you tap Stop — Sky Grid can only ask
> again, not keep it sounding.

### 2.7 Timezone / DST

Store wall-clock minutes + weekday; never a UTC instant, for both AlarmKit schedules and
the reminder fallback triggers. DST transitions require no special-case code — an alarm at
07:00 fires at 07:00 on both sides of a transition. An alarm landing inside a
spring-forward skipped hour is OS-defined behavior; accept and document rather than
special-case. Alarms follow the device's current timezone (matching the system Clock app
and matching how `posts/{localDate}` is already computed), so cross-timezone travel can
produce a doubled or skipped local date — accepted, unchanged from today's single-alarm
behavior. `resyncIfNeeded()` must run on the existing timezone-change observer so the
reminder-fallback triggers rebuild after a timezone change.

### 2.8 Failure and offline behavior

Fully offline — nothing here touches the network.

- AlarmKit authorization denied → whole set is `.denied`, unchanged semantics from today.
- Partial scheduling failure (one entry of five throws) → keep the successful ones armed,
  mark the failed row individually, do not roll back the whole set — three armed alarms
  beat zero.
- Re-alarm scheduling failure (e.g. AlarmKit throws on the follow-up shot) → fail silently
  to the existing quiet-notification handoff (§2.5's "after max attempts" row) rather than
  retrying — a failing re-alarm must never become a second bricking risk.
- Notification budget exhaustion on pre-AlarmKit iOS → prevented by the 5-alarm cap; assert
  the arithmetic in a test rather than trusting it (§2.9).

### 2.9 Acceptance criteria and test matrix

Pure Swift tests:
- migration: `morningAlarmEnabled == true` + existing `wakeGoalMinutes` → one entry, id
  equal to the legacy UUID, all 7 weekdays, enabled
- migration: `morningAlarmEnabled == false` → empty set, `wakeGoalMinutes` untouched
- migration is idempotent (running twice does not duplicate)
- derived `wakeGoalMinutes` = min over enabled entries; unchanged when the set is empty
- identifier generation: 5 alarms × 7 weekdays = 35 unique, all prefixed; prefix matches
  what `NotificationRouter`'s test asserts against
- notification budget: `35 (reminders) + 7 (follow-up window) + reserved re-alarm slots <= 64`
- weekday-summary display strings (every day / weekdays / weekends / custom)
- re-alarm: exactly 3 attempts scheduled at +5/+10/+15 minutes, no 4th
- re-alarm: date-rollover check prevents scheduling attempt N+1 across midnight
- re-alarm: capture cancels all pending attempts (assert via
  `MorningRitualCoordinator.captureCompleted`)
- reconcile: an AlarmKit id present on-device but absent from the persisted schedule set
  AND not in the re-alarm reserved prefix is cancelled; both a live schedule id and a live
  re-alarm id are preserved

`NotificationRouter` test: a prefixed identifier routes to camera; the legacy bare
identifier still routes (so a notification scheduled by a previous build and still pending
is not orphaned).

### 2.10 Dependency order and flags

Client-only; no functions, no Rules. Order within the client change:
1. `MorningAlarmSchedule` model + `LocalDefaults` keys + migration + pure tests.
2. `NotificationRouter` prefix match (**before** the scheduler emits prefixed identifiers —
   sequencing this backwards breaks routing for a real window).
3. Scheduler reconcile + follow-up scheduler weekday-awareness.
4. Re-alarm loop.
5. UI + copy (§2.6).

No feature flag: a half-migrated device is worse than either whole state, so the migration
must run unconditionally at launch. The gate for shipping is the migration test matrix, not
a runtime flag.

**Metric framing**: a **bet** on Capture-completed rate (does the reminder loop raise
same-morning capture completion?) with a stated downside risk — a user who dislikes being
re-alarmed may disable the whole morning-alarm feature, which would be a regression on the
existing single-alarm baseline. Does not directly move D7 mutual reveal.

---

## §3 — Resolution of the 6C ambiguity

### 3.1 Why the handoff brief's "6C: motion gate" framing does not match the owner's intent

The handoff brief characterized 6C as "make a motion condition mandatory" and flagged (in
its own observed-facts section) that "AlarmKit's OS Stop action occurs before app code
runs. A motion gate cannot prevent OS-level dismissal." When the owner's actual request was
clarified directly, it turned out the underlying intent was closer to *"the alarm keeps
sounding until you take the photo"* — a request for the alarm's persistence, not a
physical-motion sensor check.

**Confirmed platform constraint** (from `MorningAlarmScheduler.swift`'s own inline
documentation of AlarmKit's behavior): `AlarmManager` silences the alarm itself the instant
Stop is tapped, before any app code executes; this is system-owned and cannot be gated on
app logic. Both buttons on the alert (Stop, and the secondary "Capture the sky" action) stop
the sound. There is no code path — CoreMotion-gated or otherwise — that can keep an
AlarmKit alarm audibly sounding past a Stop tap. Any copy claiming otherwise is false.

This means the handoff brief's own explicit prohibition — "must not falsely imply that the
OS alarm remains sounding" — rules out the "keeps ringing until you move/capture" reading of
6C entirely, regardless of mechanism. What survives is the only physically achievable form
of "the morning doesn't end at Stop": bringing the alarm back repeatedly until the ritual
completes. That is the re-alarm loop specified in §2.5, which the owner reviewed and
approved as the concrete mechanism, explicitly in place of the CoreMotion gate.

### 3.2 Disposition: CoreMotion gate rejected; re-alarm loop adopted (owner-confirmed, Q4)

**The CoreMotion-based motion gate described in the handoff's observed-facts section is not
implemented.** This is a deliberate, owner-approved scope change, not a silent
downgrade — recorded here so the reasoning survives independently of this conversation:

- The act of capturing the sky photo is itself already a sufficient physical-completion
  condition — it requires reaching a window or going outside, which is the actual
  behavioral outcome a motion gate would have been trying to force indirectly.
- A CoreMotion gate would have introduced four independent failure modes that the
  capture-based re-alarm loop avoids entirely: motion-permission denial, sensor
  unavailability/silence, a mandatory timeout design (with its own bricking-risk analysis),
  and a mandatory accessibility escape hatch for mobility-impaired users (a hard-mandatory
  physical-motion requirement with no exemption path is an unshippable accessibility
  violation — see the appendix for the fuller analysis that was done before this
  disposition was reached).
- `NSMotionUsageDescription`, CoreMotion authorization UX, and a second consent surface are
  all avoided.

If a future motion-verification requirement is reintroduced, the appendix below preserves
the design work already done for it (signal choice, timeout values, accessibility
escape-hatch requirement) so it is not re-derived from scratch.

### Appendix — preserved design for a possible future CoreMotion gate (not being built now)

Kept for reference only; none of this is scheduled for implementation.

- **Signal**: `CMPedometer.startUpdates(from:)`, threshold 10 steps — chosen over
  `CMMotionActivityManager` (multi-second classification latency, not showable as progress)
  and over raw accelerometer magnitude (defeatable by shaking the phone in bed, which would
  make the gate theatre rather than a real check).
- **Timeouts, all mandatory, none optional**: sensor unavailable/denied → gate never
  presents (camera opens directly); zero sensor callbacks within 20s → auto-pass; threshold
  unmet after 120s → auto-pass with a non-shaming "Movement check timed out" line. The 120s
  ceiling exists because this codebase has **no server-side kill switch** (no Remote
  Config) — if a gate can wedge with no server-side escape, it wedges until an App Store
  update, which is unacceptable.
- **Accessibility escape hatch**: a "Can't move right now" secondary action, visible from
  the first second the gate appears (never hidden behind a delay — hiding an accessibility
  exit behind a timer is itself the violation), leading to a one-time, non-punitive,
  permanently-reversible "turn this off" setting. Explicitly rejected: gating the exemption
  behind OS accessibility signals (VoiceOver/Switch Control running) — those do not
  correlate with mobility impairment and using them to decide who "deserves" an exemption
  is both inaccurate and inappropriate.

---

## §4 — Cross-feature conflict resolution (per the handoff's explicit requirements)

- **"Must not falsely imply the OS alarm remains sounding"**: resolved by §2.6's copy rule
  and by §3.1's disposition — the mechanism that ships (re-alarm loop) is honestly
  describable, and the mechanism that would have required careful copy-hedging (a
  never-silenced alarm) was never buildable in the first place.
- **"Streak disclosure must remain compatible with mutual-reveal privacy"**: resolved by
  §1.1's pair-level definition, whose safety is a structural property (every visible change
  happens on a day already unlocked for the viewer), not a policy applied on top of a
  riskier design.
- **"The hard cap must not leave a direct client bypass"**: unaffected by this record — 1A's
  `requestBuddy`/`acceptBuddy` callables remain the only path to `accepted` status, and 3B's
  trigger only ever reads that status, never mutates it.
- **"Relationship detail must not expose posts the current relationship cannot read"**:
  unaffected — 3B adds no new read path to `posts/{localDate}`; the streak fields live on
  `friendships/{pairId}`, which both members can already read in full.

## §5 — Overall dependency order across 3B and 5C

1. **3B functions** (§1.7 step 1) — independently deployable, harmless to shipped clients,
   no client dependency.
2. **5C client work** (§2.10) — independently shippable, no functions/Rules dependency.
   These two tracks have no ordering dependency on each other and can proceed in parallel.
3. **3B client display** (`FeatureFlags.buddyStreakVisible`) — depends on step 1 having run
   for at least one full day so pairs have real data to show, otherwise every pair shows
   "counting since today," which is technically correct but a flat launch experience worth
   avoiding by sequencing.

No step here requires a Firestore Rules deploy, so none of this is subject to the
functions → rules → client release-order rule from the 1A precedent — that rule doesn't
apply because no Rules change exists in this record.

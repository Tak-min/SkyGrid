# Virality & stickiness assessment — pre-promotion

Date: 2026-09-04
Author: Opus architecture/product escalation (single pass, reused per `.loop/PROMPT.md` §2)
Scope: `.loop/VISION.md` Definition of Done item 1.
Method: direct read of live source at `/Users/taku8/Desktop/SkyGrid` on 2026-09-04. Every
status below is re-derived from code I read this session, not carried over from
`.loop/archive/audit_2026-08-08.md`.

---

## 0. Headline

The 2026-08-08 audit is **almost entirely closed**. 10 of 12 items are fixed in code; 2 remain
(B5, C3) plus one cosmetic remnant (B6b). Two of `.loop/VISION.md`'s "verified ground truth"
bullets are **wrong or stale** and would have sent this loop down an expensive path:

1. The blank `"___ : ___"` wake-time placeholder **no longer exists in code** — it was replaced
   by a streak-hero empty state (`TodayView.swift:225-251`, with an explicit comment naming the
   exact defect). VISION's claim rests on `screenshots/ui-audit-today-final.png`, which is a
   **stale artifact** — it also shows no buddy strip, which `TodayView.swift:303-334` now
   renders unconditionally. Do not "fix" this again; re-screenshot first.
2. The 1:1 → N-way buddy move is **not a data-model or Firestore-rules migration**. The pairwise
   model already supports N buddies per user, and the rules already enforce the privacy gate
   **per relationship**. See §6. This converts DoD item 4 from an architecture migration into a
   UI/copy/notification/product-limit task, and removes the second planned Opus escalation's
   original justification.

The real gap is not the audit list and not the data model. It is that **the loop's weakest stage
is the one nobody instrumented**: the invite is buried, never mentioned in onboarding, and the
inviter is never told when someone accepts.

---

## 1. Re-verification of `.loop/archive/audit_2026-08-08.md`

| ID | Original finding | Status now | Evidence (read this session) |
|----|------------------|-----------|------------------------------|
| A1 | Streak never computed/displayed; `StreakCalculator` unused in production | **FIXED** | `Today/TodayViewModel.swift:216` calls `StreakCalculator.summarize(postedDays:today:)` inside the live history observer; result published at `:47`/`:216` and rendered at `Today/TodayView.swift:153-158` (recorded card) and `:235-243` (pre-capture card). Streak is also republished to `StreakSignal` (`TodayViewModel.swift:230-236`) for milestone arbitration. |
| A2 | Buddy reveal never appears on Today; `TodayView` never read `viewModel.buddies` | **FIXED** | `Today/TodayView.swift:303-334` (`buddySection`) branches on `viewModel.buddies.isEmpty`, rendering `BuddyRow(buddies:imageFetching:)` at `:330`. Refresh triggers wired at `:68-74` (scene-phase active + `buddyRefreshToken` from push). Backing resolution at `TodayViewModel.swift:352-391`. |
| A3 | No milestone/celebration moment | **FIXED** | `Milestone/MilestoneView.swift` (full-screen, haptic at `:36`, share action `:86`/`:99-107`); thresholds `Milestone/StreakMilestone.swift:17` = `[1, 7, 14, 30, 50, 100, 200, 365]` with exact-hit + monotonic high-water-mark semantics (`:25-28`); presented from `App/RootView.swift:28`; arbitration against paywall/review covered by `Tests/PostCaptureMomentPolicyTests.swift`. |
| B1 | Year grid illegible at 31×12 aspect ratio | **FIXED** | `Grid/SkyGridView.swift:196-212` — the year block is now forced `.aspectRatio(1, contentMode: .fit)` with an in-code comment stating the ~10pt→~29pt cell change, and a separate legible month mosaic (`MonthlyPhotoGrid`, `:357-383`) carries the actual photos. |
| B2 | Raw internal error leaked on startup failure | **FIXED** | `App/StartupFailureMessage.swift:23-38` maps every `AppStartupError` to two human sentences; diagnostic text is routed to `Logger` only via `:42-49`. |
| B3 | Blank `"—:—"` / `"___ : ___"` wake-time placeholder reads as broken glyph | **FIXED — VISION.md is stale here** | `Today/TodayView.swift:225-251`: the placeholder clock is gone; the pre-capture hero is now the streak numeral (`:236-243`) or `"Day one" / "your first sky is today"` (`:245-250`). The comment at `:226-230` names the exact "detached hairlines and floating dots" defect. `screenshots/ui-audit-today-final.png` predates this and predates A2. |
| B4 | Archive notice clipped by tab bar | **FIXED** | `Grid/SkyGridView.swift:70-72` uses `.safeAreaInset(edge:.bottom)` on the scroll container (comment at `:63-69` explains why content padding was insufficient); same fix in `Friends/BuddiesView.swift:195` and `Today/TodayView.swift:62`. |
| B5 | Buddy list rows carry no info | **STILL OPEN** | `Friends/BuddiesView.swift:256-273` — `BuddyNameRow` renders exactly `Text(displayName ?? "Buddy")` plus a `NavigationLink` chevron into a **Safety** screen. No streak, no last-capture date, no handle, no reveal state. Confirmed visually in `screenshots/ui-audit-buddies-final.png` ("Mira", "Ren"). The row's only destination is Block/Report — the buddy list's sole interaction is punitive. |
| B6 | Disabled button weak contrast | **FIXED (primary) / OPEN (secondary)** | `DesignSystem/ViewModifiers.swift:45-71` — `SkyPrimaryButtonStyle` now renders disabled as an unfilled stroked capsule with `SGT.ink3`, with a comment naming the "Send request" case. `SkySecondaryButtonStyle:86` still uses a flat `.opacity(0.42)` when disabled — the same failure mode, one style over. LOW. |
| C1 | Share card unreadable at thumbnail size | **FIXED — and VISION.md's description is out of date** | VISION says "QR + App Store URL were added". In fact the **QR was removed on 2026-08-11** and replaced by a full-width identity ticket (`Grid/AppStoreIdentityExportView.swift:7-20`, with the correct reasoning: a Story is watched on the same phone that would scan it). Thumbnail legibility was separately rebuilt on 2026-08-11: `Grid/SkyGridExportView.swift:14-27` replaced the literal 31×12 hero (94% empty for a 20-capture user, ~3px tiles at story-tray size) with `CapturedSkyMosaicExportView` (packed, ~146pt tiles) plus a small `YearMapExportView` truth-keeper. The headline numeral is 232pt on a 1080-wide card (`:103`) ≈ 21% of card width — legible at ~120px. Streak **is** included on the morning card (`Grid/MorningCardExportView.swift:123-131`). |
| C2 | No day-1 shareable artifact, only full-year export | **FIXED** | `Grid/MorningCardExportView.swift` (single-morning 9:16 card, deliberately sharing the year card's grammar — `:11-15`), rendered by `Grid/ShareCardRenderer.renderMorning` (`:26-37`), reachable from day 1 because `StreakMilestone.thresholds` includes `1` (`StreakMilestone.swift:17`). **Caveat below.** |
| C3 | Onboarding sells calm, not the mechanic | **STILL OPEN** | `Onboarding/OnboardingCoordinatorView.swift:4-13` — 8 steps: welcome → intention → pace → frequency → privacy → reminder → wakeGoal → plan. **Zero** steps mention a buddy, mutual reveal, or a streak. `Onboarding/WelcomeView.swift:15-21` still says *"Keep one morning sky. / Its color becomes one quiet day in your grid."* — which is (a) calm-first and (b) **factually stale**: the product converted from averaged colour to actual photos (commit `82f39a3`), so the one promise the first screen makes is no longer what the app does. |

### Two defects found this session that the 2026-08-08 audit did not have

- **D1 (HIGH, new): the day-1 share card is only reachable through a milestone.** Every call
  site of `renderMorning` is `MilestoneView` (`Grid/ShareCardRenderer.swift:26` ← `Milestone/MilestoneView.swift:100`;
  the only other reference is the audit harness at `App/SkyGridApp.swift:148`). There is **no
  share affordance on Today for an ordinary morning** — `TodayView` has no `ShareSheet`/`ShareLink`
  at all. So the artifact exists but is gated behind `streak ∈ {1,7,14,30,…}` and, per
  `StreakMilestone.reached` (`:25-28`), fires at most once per threshold per install. A user on
  day 3 who takes a beautiful sky has nothing to share. C2 is fixed as an *asset*, not as a *loop*.
- **D2 (HIGH, new): the inviter is never notified that their invite was accepted.**
  `ios/functions/src/index.ts` exports exactly one Firestore trigger — `onBuddyPostCreated`
  (`:510`). There is no `onFriendshipCreated`. `claimInviteCode` writes the friendship as
  `accepted` server-side inside the transaction (`inviteStore.ts:381-391`), so the pairing is
  instant — but the person who sent the link learns about it only by opening the app and hitting
  `refreshBuddiesNow`. The single highest-intent moment in the whole loop produces no push.

---

## 2. The loop, as it will exist after this loop's planned changes (DoD 3–7)

Modelled concretely against the code paths that exist or are planned. Stage names per the kernel.

**Stage 1 — Trigger (internal).**
`MorningAlarmScheduler` fires an AlarmKit system alarm at the configured wake time
(`Notifications/MorningAlarmScheduler.swift:282-294`, weekly-all-days, single fixed
`alarmIdentifier` at `:60`). DoD 5 adds N configurable times and a motion/action-gated dismissal.
Secondary trigger: `onBuddyPostCreated` push when a buddy posts (`index.ts:510`), routed to
`TodayView` via `buddyRefreshToken` (`TodayView.swift:72-74`). Tertiary: `MorningFollowUpScheduler`
nudges.
*Sensitivity:* this stage is the app's strongest. AlarmKit on iOS 26 is a genuine OS alarm, not a
notification. Multi-alarm and motion-gating raise **completion probability given the trigger
fired**, not trigger reach.

**Stage 2 — User action (in-app, private).**
Alarm → `OpenMorningCameraIntent` foregrounds the app (`MorningAlarmScheduler.swift:334-349`) →
camera → `PostPublisher` writes `users/{uid}/posts/{localDate}` → `TodayViewModel.observePost`
sees it → `refreshBuddies` re-runs because *this is the exact moment the server begins permitting
buddy post reads* (`TodayViewModel.swift:146-155`). Streak recomputes; `StreakSignal` publishes;
`PostCaptureMomentPolicy` arbitrates milestone vs. paywall vs. review.
*Sensitivity:* high and already well-built. The motion-gated dismissal (DoD 5) is a **Stage 1→2
conversion** lever, not a virality lever. Do not count it as growth.

**Stage 3 — External artifact / contact.** *This is the broken stage.*
Two distinct sub-paths, and they are asymmetric in quality:

- **3a — the invite link (contact).** `Invite/InviteLinkCard.swift` → `createInvite` callable →
  a real universal-link URL with expiry, single-use, revocation, and rate limiting
  (`inviteStore.ts`, `invites.ts`). This is a genuinely good piece of engineering.
  It is reachable only from **tab 3 → scroll past a 3-step explainer card
  (`BuddiesView.swift:205-235`) → past an "Invite a buddy" handle form (`:95-98`) → to
  `InviteLinkCard` (`:100`)**. It requires a claimed handle first (server-enforced:
  `inviteStore.ts:337-340` throws `MissingHandleError`). Onboarding never mentions it (§1/C3).
- **3b — the share card (artifact).** `MorningCardExportView` / `SkyGridExportView` → `ShareSheet`.
  Gated behind a milestone (D1). Carries `SHARED BY @handle` + app icon + "SEARCH"
  (`AppStoreIdentityExportView.swift:35-60`) — **no link, no code, no deep link**. By design
  (Stories can't carry taps), but it means 3b's conversion to Stage 4 is search-driven, i.e. weak
  and unmeasurable.

DoD 6 (share rebuild) should be read as: **3b's job is App Store discovery; 3a's job is loop
closure.** They are not the same artifact and should not be optimized as one.

**Stage 4 — Recipient activation.**
`InviteLinkParser` → `InviteClaimView` → `previewInvite` (shows creator handle + expiry) →
inline `HandleClaimView` if the recipient has no handle (`Invite/InviteClaimView.swift:42`) →
`claimInviteCode` → friendship written directly as `accepted` (`inviteStore.ts:385`), skipping the
pending/accept round trip. Instrumented: `previewViewed` → `claimStarted` → `claimResolved`
(`Invite/InviteAnalytics.swift:9-17`).
*This sub-stage is the best-built part of the loop.* Its weakness is upstream (few links get sent)
and downstream (D2: the inviter isn't told).

**Stage 5 — Repeat.**
The recipient now has ≥1 buddy → their Today shows a sealed disc row
(`TodayView.swift:327-333`, label `"SEALED UNTIL YOU POST"`) → posting is the only way to unlock
→ that generates `onBuddyPostCreated` back to the inviter → the inviter's Stage 1 trigger is now
partly **social**, not just an alarm. That is the actual retention flywheel and it already works.
After DoD 4 (N-way), each additional circle member adds one more independent daily push source
and one more sealed disc — i.e. Stage 5 strength scales with circle size, which is exactly why the
circle-size product limit (§6) is a growth decision, not a technical one.

**Where the loop actually breaks:** Stage 2 → Stage 3a. Everything before it is strong and
everything after it is strong. A user is never asked to invite anyone at the one moment they have
just proved they care (post-capture), and the app's own copy tells them to invite *one* person
(`BuddiesView.swift:212` "Two skies, revealed together", `:217` "Invite one trusted person",
`TodayView.swift:310` "Invite one person") — a self-imposed viral coefficient ceiling of ~1 with
no technical basis (§6).

---

## 3. Target metric

**One metric this loop optimizes: D7 mutual-reveal rate** — of installs in a cohort, the share
that reach ≥1 *mutually revealed morning* (viewer posted AND ≥1 buddy's post successfully read)
within 7 days of install.

Why this one and not "D7 retention" or "share rate":
- It is the only single event that requires all five loop stages to have fired at least once
  (trigger → capture → invite sent → invite claimed → both posted on the same local day).
- It is **server-verified, not inferrable**: `revealState == .posted` can only be produced after
  `firestore.rules`' `activeBuddy(uid) && hasPostedFor(localDate)` permitted the read — the code
  says so explicitly at `TodayViewModel.swift:382-385`. A client cannot fake it.
- The plumbing already exists: `RevealSignal.record(RevealReading(...))` fires with
  `mutuallyUnlockedBuddyCount` on every buddy refresh (`TodayViewModel.swift:386-390`). It is
  consumed only by the solo-morning paywall policy today.
- It is monetization-adjacent, which matters for the paid-retention half of the brief.

**Current value: `unmeasured`.**
Evidence, not assumption: FirebaseAnalytics is linked (`ios/project.yml:48`) and is used in
exactly two places — `Paywall/PaywallAnalytics.swift` and `Invite/InviteAnalytics.swift`. Grep for
`logEvent` across the repo returns only those two files. There is **no** capture event, no streak
event, no share event, no reveal event, no retention event. `RevealSignal` never reaches
analytics. So: the invite *funnel* (created → shared → preview → claim) is instrumented but I have
no console access and therefore no values; the reveal metric is not instrumented at all.

**Cheapest instrumentation (do this before, not after, the visual pass):**
one `Analytics.logEvent` in `performRefreshBuddies` (`TodayViewModel.swift:381-390`) on the
`0 → ≥1` transition of `mutuallyUnlockedBuddyCount`, plus a `skygrid_capture_completed` event in
`PostPublisher`. Two events, no new dependency, no PII (follow `InviteAnalytics`'s existing
no-uid/no-handle discipline, `InviteAnalytics.swift:4-7`). Without these, every claim this loop
makes about stickiness stays a bet.

**Counterfactual — what happens if DoD 3–7 are not done:**
The app remains a well-built single-player morning-photo journal with a working but effectively
hidden social layer. Concretely: a new install completes an 8-step onboarding that never mentions
another human (`OnboardingCoordinatorView.swift:4-13`), lands on a Today screen whose buddy
affordance is a quiet grey card below the fold (`TodayView.swift:304-326`), and — if they never
tap tab 3 — will never encounter the mutual-reveal mechanic at all. In that state the loop's
branching factor is 0 and influencer spend buys linear, decaying installs: cost-per-install with
no multiplier and no referral tail. The retention argument also weakens, because the strongest
retention signal in the codebase (a buddy's push at `index.ts:510`) only exists for paired users.
That is the specific reason to hold the collabstr seeding, and it is a code-grounded reason, not
a vibe.

---

## 4. Claims (verified in code/screenshots this session)

1. All of A1, A2, A3, B1, B2, B3, B4, C1, C2 are fixed in `main` as of 2026-09-04; B5 and C3
   are open; B6 is fixed for the primary button style only. Evidence table in §1.
2. `.loop/VISION.md`'s "blank `___ : ___` placeholder is still open" is **false against current
   code** (`TodayView.swift:225-251`); the supporting screenshot is stale.
3. `.loop/VISION.md`'s "QR + App Store URL were added" is **inverted**: the QR was deliberately
   removed 2026-08-11 (`AppStoreIdentityExportView.swift:7-13`).
4. The buddy data model already supports N buddies per user; the reveal gate is already
   per-relationship and server-enforced. See §6 for the full argument.
5. Multi-alarm does not exist: one fixed `alarmIdentifier` (`MorningAlarmScheduler.swift:60`),
   one `wakeGoalMinutes` (`:76`), one repeating weekly schedule (`:282-287`).
6. No motion-gated dismissal exists: the AlarmKit presentation offers a plain `Stop` button plus a
   "Capture the sky" secondary (`MorningAlarmScheduler.swift:305-320`), and
   `MorningAlarmStoppedIntent` documents that the OS has *already silenced the alarm* before app
   code runs (`:352-358`). **This is a hard platform constraint that constrains DoD 5** — see Bet 4.
7. The day-1 share card is only reachable via a milestone (D1). Today has no share affordance.
8. No server trigger notifies an inviter that their invite was claimed (D2); `index.ts` has one
   Firestore trigger only (`:510`).
9. Analytics coverage is paywall + invite only; capture, streak, share, and reveal are
   uninstrumented.
10. `performRefreshBuddies` issues **2 uncached snapshot reads per buddy per refresh** (profile
    `:357`, post `:365`) and is invoked on every scene-phase activation (`TodayView.swift:68-71`),
    every buddy push (`:72-74`), and every friendship snapshot (`TodayViewModel.swift:177`). It is
    **uncapped**, while the UI displays at most 12 (`BuddyRow.swift:15`).
11. The onboarding welcome copy promises a *colour* record (`WelcomeView.swift:19`), which the
    product no longer is (commit `82f39a3` replaced averaged colour with actual photos).

## 5. Bets (assumption → cheapest test → exit condition)

Each of these is a bet, not a claim. None has user evidence, and none should be written up later
as if it did.

**Bet 1 — Visual pass (DoD 3).**
*Assumption:* the "~60/100, AI-generated-generic" read is driven mainly by **information
hierarchy and stale copy**, not by the palette/typeface. The warm-cream/serif system is
distinctive; what reads as template is (a) buddies-tab screens leading with explainer cards
instead of state, (b) rows carrying no information (B5), (c) first-screen copy describing a
product that no longer exists (§4.11).
*Cheapest test:* rebuild Today/Buddies with §7's hierarchy, re-shoot the three audit screenshots,
and put old/new side by side for the product owner. One binary judgement, no code risk.
*Exit condition:* if the owner still reads the new screens as generic, the problem is the design
system itself (palette/type), not hierarchy — stop iterating on layout and escalate the type/colour
system separately. Do not do a third layout round.

**Bet 2 — Circle beyond 1:1 (DoD 4).**
*Assumption:* the ceiling on mutual-reveal rate is set by *"invite exactly one trusted person"*
being both the copy and the mental model — one person who defects kills the loop for both. A
3–8 person circle makes at least one daily reveal likely even when any single member misses.
*Cheapest test:* this needs **no migration** (§6). Ship copy + UI for N, cap the circle at 8, and
compare mutual-reveal rate (once instrumented) for users with 1 buddy vs ≥2. That comparison is
available from existing data the moment the metric exists.
*Exit condition:* if users with ≥2 buddies do not show a higher mutual-reveal rate than users
with 1, the constraint is not circle size — it is invite *sending*, and effort should move
entirely to Stage 3a placement (Bet 3).
*Risk to hold:* a bigger circle makes the sealed row a feed. `TodayView.swift:297-301` states
"one object with no decisions attached… does not turn the pre-capture screen into a feed" as an
explicit design invariant. Honour it: the row stays discs, not cards.

**Bet 3 — Invite placement (not currently a DoD item; recommend adding it).**
*Assumption:* Stage 2→3a is the loop's binding constraint, and the fix is placement, not
mechanics — the invite machinery already works.
*Cheapest test:* add one invite affordance immediately after the *first successful capture*
(alongside/inside the existing day-1 `MilestoneView`, which already exists and already fires at
streak 1), plus the D2 push to the inviter on claim. Both are small. Then read
`skygrid_invite_link_shared` and `skygrid_invite_claim_resolved` — **already instrumented**
(`InviteAnalytics.swift:11,16`), so this is measurable on day one with no new events.
*Exit condition:* if `linkShared` per new install does not move materially after the placement
change, the problem is desire (nobody wants to invite anyone to this), not friction — which is a
much more serious product finding and should stop the promotion decision outright.

**Bet 4 — Motion-gated dismissal (DoD 5).**
*Assumption:* forcing a physical action before silence raises capture-given-alarm-fired.
*Constraint that must shape the design (this is a claim, not a bet):* AlarmKit silences the alarm
before app code runs (`MorningAlarmScheduler.swift:352-358`). **You cannot gate the OS alarm's
Stop button.** So the only honest mechanics are: (i) make "Capture the sky" the *only* alert
button on iOS 26.1+ — `makeAlertPresentation` already does exactly this at `:307-312`, so the
alert is already close to gated — and (ii) gate the *Live Activity / in-app dismissal* of the
"sky not captured yet" state on a physical action (e.g. the capture itself, or a stand-up motion
detected via CoreMotion before the shutter unlocks).
*Cheapest test:* implement (ii) as a shutter precondition on the camera screen only, behind a
setting, and measure capture-completion. Do not touch `MorningAlarmScheduler`'s AlarmKit path.
*Exit condition:* if completion does not improve, remove it — a motion gate that doesn't work is
pure friction on the app's most fragile moment (a half-awake person at 6am), and shipping it
anyway would be a net negative.

**Bet 5 — Share rebuild (DoD 6).**
*Assumption:* the *artifact* is no longer the constraint (C1/C2 are genuinely fixed and the cards
are good); the *access path* is (D1).
*Cheapest test:* add a share button to Today's recorded-morning card, reusing
`ShareCardRenderer.renderMorning` unchanged. One button, zero new rendering code.
*Exit condition:* if share volume stays near zero with a first-class share affordance present,
stop investing in the share artifact entirely and treat App Store discovery as paid-only — the
card is not the growth channel and further design work on it is sunk cost.

**Bet 6 — Multi-alarm (DoD 5).**
*Assumption:* one fixed wake time loses weekend/shift users who then break their streak and churn.
*Cheapest test:* before building N alarms, look at whether missed days cluster on weekends —
computable from existing post data with no new instrumentation.
*Exit condition:* if missed days are uniform across weekdays, multi-alarm is solving a problem
that isn't there; defer it and spend the effort on Bet 3.

---

## 6. Buddy-model architecture: VISION.md's note is **incorrect** — correction + direction

### What VISION.md says
> "Buddy system is 1:1 at every layer… Moving to a BeReal-style closed group is a **real
> data-model and rules migration**, not a UI reskin."

### What the code says
Every individual fact cited in that bullet is true; the conclusion drawn from them is not.

- `PairID.make` (`Models/Friendship.swift:12-16`) produces one doc id **per pair**. Nothing
  restricts a user to one pair. `friendships/{pairId}` is a flat collection of edges.
- `members: [String]` size 2 and `otherMember(than:)` (`Friendship.swift:51-53`) are correct *for
  an edge*. They are not a global cardinality constraint.
- `FriendRepository.observeFriendships(uid:)` returns `[Friendship]` — **a list**
  (`Data/FriendRepository.swift:31`). `FriendsViewModel.accepted` is a list. `TodayViewModel.buddies`
  is a list. `BuddyRow` already iterates and renders up to 12 (`Today/BuddyRow.swift:15`).
  `performRefreshBuddies` already loops over N friendships (`TodayViewModel.swift:355-379`).
- `firestore.rules`' `activeBuddy(uid)` (`ios/firestore.rules:16-23`) is a *single-uid predicate
  evaluated per target user* — which is precisely the per-relationship gate DoD 4 asks for. The
  post rule at `:118-119` reads `request.auth.uid == uid || (activeBuddy(uid) && hasPostedFor(localDate))`:
  to see B's sky, A must be an active buddy **of B specifically** and A must have posted. There is
  no global unlock anywhere in the rules.
- There is **no server-side cap** on friendships. `inviteGeneration` (`inviteStore.ts:258`,
  `invites.ts:68-71`) merely *stamps* whether the creator already had a buddy — it is explicitly
  "not currently consumed by the client" (`Invite/InviteModels.swift:56-58`). It gates nothing.

**Conclusion: the N-way capability already exists end to end.** The 1:1-ness is *copy and UI
framing* — `"Invite one person"` (`TodayView.swift:310`), `"Two skies, revealed together."`
(`BuddiesView.swift:212`), `"Invite one trusted person"` (`:217`). DoD item 4 is a UI + copy +
notification + product-limit task. **Recommend cancelling the planned second Opus escalation for
a data-model migration** — there is nothing to migrate.

### Directional recommendation

**Keep pairwise edges. Do not introduce a group document.** Model the "circle" as an *ego network*
(the set of A's accepted edges), rendered as a group, not as a shared group entity.

Rationale, and the risk that decides it:
- A group doc with per-member subcollection state would require the reveal gate to be evaluated
  against *group membership* rather than against *a specific relationship*. That is exactly the
  "unlocked for everyone once anyone posts" failure mode VISION.md's guardrail forbids, and it
  would have to be re-derived in Rules from scratch. The current rule is 8 lines, already correct,
  already shipped, and already covered by the `hasPostedFor` post rule. **Rewriting a working,
  server-enforced privacy boundary to gain nothing is the single largest avoidable risk in this
  loop.**
- Ego-network semantics also preserve consent correctly: A↔B and A↔C do **not** imply B↔C.
  A true BeReal-style shared group *does* imply it, which means adding someone to your circle
  would expose your existing members' skies to a stranger they never accepted. That is a
  regression in the product's core promise ("one trusted person"), not a feature.

**What actually has to change (all additive):**

1. **Copy/UI**, everywhere the singular is asserted (`TodayView.swift:310-313`,
   `BuddiesView.swift:212-224`, onboarding). This is the bulk of DoD 4.
2. **A product-level circle cap.** Currently unbounded. Recommend **8**, enforced in
   `claimInviteCode` (`inviteStore.ts`, in the same transaction that creates the friendship —
   it already reads the caller's friendship summaries at `:258`) and mirrored in the client for a
   clean error. Rules cannot count a user's edges without a fan-out counter, so **enforce
   server-side in the callable, not in Rules** — and be explicit that the callable is the
   enforcement point, so nobody later assumes Rules guarantee it.
3. **Bound the read fan-out (do this with, not after, the N-way UI).**
   `performRefreshBuddies` does 2 snapshot reads per buddy (`TodayViewModel.swift:357, 365`) and is
   uncapped, while `activeBuddy()` itself costs an extra billed `get()` per post read
   (`firestore.rules:19`). At N=1 that's ~4 reads per refresh; at N=8 it's ~32, on every
   foreground and every buddy push. Cap the loop to the same 12 the UI shows, and prefer batching
   profiles. Preserve `BuddyTile.loadThumbnail`'s cancellable `.task(id:)` behaviour exactly, per
   VISION.md's guardrail — that part is not the problem.
4. **Notifications must move with the model (DoD 4 says so, and D2 makes it urgent):** add an
   `onFriendshipCreated` trigger for "X joined your circle", and confirm `onBuddyPostCreated`
   fans out to *all* of the poster's accepted edges rather than assuming one.
5. **Preserve the `sealed` / `posted` / `notYet` tri-state** (`TodayViewModel.swift:21-30`) per
   buddy. At N-way it becomes more important, not less: a denied read must never render as
   "they haven't posted" for any member.

**Explicitly out of scope / recommend against:** a `circles/{circleId}` document, per-member
subcollections, and any change to the `friendships/{pairId}` shape or to `firestore.rules`' post
read rule. If a later product decision genuinely requires B↔C visibility, that is a *new consent
model* and needs its own escalation — it is not a refactor of this one.

---

## 7. Design direction for the visual pass (DoD 3)

Prioritized. Each item names the concrete failure it closes. Implementation belongs to other
agents in this loop; this section is the brief they build against.

**P0 — Buddies tab: invert the hierarchy (closes B5, and the "generic wellness template" read).**
Today the screen leads with a 3-step explainer card (`BuddiesView.swift:205-235`), then a form,
then — below the fold — the actual people, rendered as bare names whose only destination is
Block/Report. That ordering is what makes it read as a template: *explanation first, state last*.
Invert it.
- Circle state at the top: each member as a row carrying **their current streak, whether they've
  captured today (using the existing `sealed`/`posted`/`notYet` tri-state, never a fabricated
  "not yet"), and their handle**. A row must answer "how is this relationship doing" without a tap.
- The explainer card collapses to a single line once the user has ≥1 buddy — it is onboarding
  content, not permanent chrome.
- The row's primary destination becomes the relationship, not Safety. Block/Report moves to a
  swipe action or an overflow. A social screen whose only verb is "report" reads as a moderation
  console.
- Empty state: replace "No buddies yet / When you both capture the morning, you reveal each
  other's sky." (`:154-157`) with a **single primary action** — the invite link, which is
  currently the third thing on the screen. The empty state's job is to produce a sent link, not to
  explain a mechanic.

**P0 — Add the missing loop affordances (closes D1, D2, and Bet 3's test).**
- A share control on Today's recorded-morning card (`TodayView.swift:146-171`), calling the
  existing `renderMorning` unchanged.
- An invite prompt in the day-1 milestone (`MilestoneView.swift:84-93` already has a two-button
  actions stack — this is where it goes, next to "Share this morning").
Neither is a "visual" change strictly, but both are the reason the visual pass exists, and both
are cheap.

**P1 — Onboarding: sell the mechanic (closes C3, and fixes the stale colour promise).**
- `WelcomeView.swift:15-21` must stop promising a colour record. The product is photographs.
- Add **one** step, before `wakeGoal`, that shows the mechanic as an image rather than words: two
  sealed discs → both unseal. This is the product's only genuinely differentiated idea and it
  currently appears nowhere before tab 3.
- Add an invite step at the end (skippable, one tap to `createInvite` + share sheet). This is the
  single highest-leverage change available for the target metric.
- The existing 8 steps are already long. **Adding two means cutting two** — `pace` and `frequency`
  feed `PersonalizationProfile`, which drives copy in `PersonalizedPlanView`; verify what actually
  consumes them before cutting, but do cut. A 10-step onboarding that never mentions the mechanic
  is worse than an 8-step one that does.

**P1 — Today: raise the pre-capture card's stopping power (the one live item from VISION's ground truth).**
B3's placeholder is gone, but the *card* is still a pale blue→cream gradient with a soft white
blur circle (`TodayView.swift:191-207`, `:380-386`) — VISION's "low stopping power" critique
survives its placeholder critique. Direction:
- Anchor the card in **yesterday's actual photo**, heavily darkened, rather than a synthetic
  gradient. The app already has the photo and already loads it (`WeekRhythmView`, `BuddyTile`).
  "Here is the sky you kept yesterday; today's is missing" is a far stronger pre-capture statement
  than an abstract gradient, and it makes the empty state *about the streak you're about to break*.
  Fall back to the current gradient on day 1 / cache miss — do not invent a photo.
- Keep the streak numeral as the hero (`:236-239`); it is the right call and is working.
- The `"Free"` plan badge (`:134-142`) currently sits at the top-right, level with the app title,
  which gives billing status equal weight to the product name on the app's primary screen. Demote
  it to Settings or to the paywall entry point.

**P2 — Grid.** Already the strongest screen (B1 fixed, mosaic legible). Only change: the
`"{n} / 365"` counter (`SkyGridView.swift:154`) frames the year as a completion percentage a user
will never reach, i.e. as a permanent 94%-failure readout. Prefer the count alone, matching the
share card's own framing ("N morning skies photographed this year",
`SkyGridExportView.swift:99-122`) — which is already the better line and is already written.

**P2 — Share.** Do not redesign. C1/C2 are fixed and the cards are the most considered surface in
the app. The only change worth making is consistency with any new circle framing.

**P2 — Paywall.** Out of scope for critique this pass — it is the only surface with real analytics
(`PaywallAnalytics.swift`), so it should be changed against data, not against this read. Flag only:
`SkySecondaryButtonStyle`'s disabled `.opacity(0.42)` (`ViewModifiers.swift:86`) is the last
instance of the B6 defect and should be brought in line with the primary style.

**Cross-cutting.** Follow the existing repo discipline: one `quietCard()` surface
(`ViewModifiers.swift:7-22`), one motion path through `skyAnimation` (`:26-40`), `SGT` tokens in
app and `SGExport` tokens in artifacts (the `*ExportView.swift` filename boundary in
`ExportTheme.swift` is a real, enforced convention — do not break it). Every one of those already
exists; the generic feeling is not coming from the token layer.

---

## 8. Open questions this pass could not answer

- **Actual funnel values.** `skygrid_invite_*` and `skygrid_paywall_*` have been shipping for
  weeks. Someone with Firebase console access should read them **before** the visual pass, because
  they may contradict Bet 3 entirely (e.g. if links *are* being sent and *not* claimed, the
  problem is Stage 4 copy, not Stage 3a placement, and §7's P0 is misprioritized).
- **Whether `pace` / `frequency` onboarding answers change anything downstream.** Needed before
  cutting them.
- **Weekend clustering of missed days** (Bet 6's test). Computable from existing post data.

---

*Files whose content is load-bearing above: `ios/SkyGrid/Sources/Today/TodayView.swift`,
`ios/SkyGrid/Sources/Today/TodayViewModel.swift`, `ios/firestore.rules`,
`ios/SkyGrid/Sources/Models/Friendship.swift`, `ios/functions/src/inviteStore.ts`,
`ios/functions/src/index.ts`, `ios/SkyGrid/Sources/Friends/BuddiesView.swift`,
`ios/SkyGrid/Sources/Notifications/MorningAlarmScheduler.swift`,
`ios/SkyGrid/Sources/Onboarding/OnboardingCoordinatorView.swift`.*

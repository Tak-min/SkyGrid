# LOOP VISION — Pre-promotion design & stickiness overhaul (started 2026-09-04)

## PIVOT (2026-09-04, human): this loop no longer implements code

Per explicit instruction, this loop's job is now **problem discovery + abstracted improvement
proposals only** — no more Swift/Firestore implementation happens inside this Claude Code loop.
The headless implementation driver (`loop-engine.sh`) was stopped; do not relaunch it against
`.loop/verify.sh` (that gate assumes code-implementation DoD items and will never pass under the
new scope). Accumulated findings are handed off in batches to a separately-running Codex CLI
session (another terminal window, operated directly by the assistant), which does the actual
codebase verification and implementation. Everything below this point (the original DoD, the
code-implementation guardrails, the driver-specific notes) is **historical record of the
discovery work already done** — keep it as source material for future findings, but stop treating
DoD items 3-8 as something this loop will build. `dev-notes/virality-stickiness-assessment_2026-09-04.md`
is the first (and, at time of pivot, only) findings/proposals batch handed to Codex.

## Why this loop exists

The 2026-08-21 collabstr influencer shortlist is **paused**. Before spending on influencer
seeding, the product owner wants proof the app itself can sustain a daily-morning-habit +
paid-retention loop, not a feature checklist. Their own read, unsoftened: current execution is
**~60/100**, parts of it "feel AI-generated-generic", and it is genuinely unclear a user would
form the habit or pay. This loop's job is to close that gap — critically, with evidence, not
with "we implemented X so people will love it" reasoning.

Historical context lives in `.loop/archive/` (prior loop: photo-over-color conversion, closed
2026-08-14) and `dev-notes/*.md`. Do not re-read all of it; `VISION.md` here is the current
source of truth. `.loop/archive/audit_2026-08-08.md` found real virality defects (share card
unreadable at thumbnail size, no day-1 shareable artifact, onboarding sells calm not the
mechanic) — **re-verify each item against live code first**, several were already fixed in a
later 2026-08-08 session (streak+reveal wiring, QR/App-Store-URL on the share card).

## Verified ground truth (confirmed by direct code read 2026-09-04 — do not re-derive)

- **CORRECTION (2026-09-04, Opus re-verification — see
  `dev-notes/virality-stickiness-assessment_2026-09-04.md` §6):** the bullet below (kept for
  history, struck by this correction) was wrong. `PairID.make` producing one doc id per pair,
  `members: [String]` size 2, and `activeBuddy(uid)` being a single-uid predicate are all true
  **per edge**, but nothing caps a user to one edge: `FriendRepository.observeFriendships`
  already returns `[Friendship]`, `TodayViewModel.buddies` is already a list, `BuddyRow` already
  renders up to 12. The Firestore rule is already evaluated **per relationship**, which is
  exactly what an N-way per-person mutual-reveal gate needs — there is no global unlock to fix.
  **The N-way buddy move (DoD 4) is a UI/copy/notification/product-limit-cap task, not a
  data-model or Firestore-rules migration.** The second Opus escalation originally planned for
  "buddy 1:1 → N-way group data-model + Firestore rules migration design" is **cancelled** —
  there is nothing to migrate; see the dev-note §6 for the ego-network directional recommendation
  (keep pairwise edges, add a server-side circle cap, do not introduce a group document).
- ~~Buddy system is 1:1 at every layer, not just copy: `Friendship.swift`'s `PairID.make`
  produces one deterministic `{a}_{b}` doc id per pair, `members: [String]` is always size 2,
  `otherMember(than:)` assumes exactly one other person, and `firestore.rules`'
  `activeBuddy(uid)`/`relationshipWith(uid)` are single-uid functions built on that same pairId
  scheme. Moving to a BeReal-style closed group (N members, each gated by their own
  mutual-reveal state) is a real data-model and rules migration, not a UI reskin — treat it
  as an architecture decision, not an implementation detail.~~ *(superseded by the correction
  above)*
- **Buddy photo loading is already async/non-blocking.** `BuddyTile.loadThumbnail` runs in a
  cancellable `.task(id:)` keyed to the post identity, shows the server-verified `skyColor` as
  fallback while the real photo streams in via `ThumbnailLoader`. This is not a gap — preserve
  this behavior exactly when the buddy model becomes N-way; do not re-architect it.
- **Alarm system supports exactly one wake time.** `MorningAlarmScheduler` has a single
  `alarmIdentifier` / `hasMorningAlarm` check — no array of alarms, no per-alarm state.
- **No Erly-style motion-gated dismissal exists.** Current AlarmKit integration is a standard
  stop button; nothing requires a specific physical action to silence it.
- **Mutual-reveal privacy gate is real and correctly enforced server-side**
  (`firestore.rules` `hasPostedFor(localDate)` + the post `get`/`list` rule), not just a client
  blur — any redesign must preserve this invariant per-person in the N-way model.
- Screenshots (`screenshots/ui-audit-today-final.png`, `ui-audit-buddies-final.png`) show a
  deliberate warm-cream/serif/muted-palette minimalism — this is **not** literally AI-slop
  (no purple gradients, no glassmorphism, no generic SF-rounded-everything), but it has
  specific, fixable failure points: a pale gradient card with low visual "stopping power", and a
  buddies-tab empty state that reads as a generic wellness-app template rather than a
  considered product. Ground the redesign in concrete critique like this, not vibes.
  **CORRECTION (2026-09-04):** the "blank `___ : ___` wake-time placeholder" item above is
  **stale** — `TodayView.swift:225-251` already replaced it with a streak-hero empty state; the
  screenshot predates that fix (and predates the buddy-strip wiring). Re-shoot screenshots before
  claiming any before/after in the DoD-3 visual pass. See
  `dev-notes/virality-stickiness-assessment_2026-09-04.md` §1 (B3) for the file:line evidence.
- **CORRECTION (2026-09-04, human resume session):** "211 tests, all green" was **not actually
  true** — the iteration-1 verify command was broken (piped through `tail`, which always exits 0,
  so a real xcodebuild failure was read as a pass) and separately was missing `-project`/`-scheme`
  entirely. Running it correctly (`xcodebuild test -project SkyGrid.xcodeproj -scheme SkyGrid
  -only-testing:SkyGridTests -destination 'platform=iOS Simulator,name=iPhone 17'`) shows **211
  tests, 2 failing**: `CollectionObservationStateTests.gridPreservesLastConfirmedPosts()`
  (`ios/SkyGrid/Tests/OrphanedPostRecoveryTests.swift:308`). `git diff 200d2e4..HEAD --stat` shows
  no `ios/` Swift file was touched by iteration 1, so this failure **predates this loop** — it is
  not a regression from anything done here, but it must still be fixed before DoD-8 can be met.
  See PROMPT.md for the corrected verify command. Investigate this test as an early TODO item
  (likely a `Task.yield()`-count race against `GridArchiveViewModel`'s async pipeline, not a real
  logic bug — confirm before changing production code to fit the test).

## Definition of Done (loop stops here)

All of the following, each independently verified:

1. **Written critical analysis** (`dev-notes/virality-stickiness-assessment_<date>.md`) modeling
   the actual trigger → user action → external artifact/contact → recipient activation → repeat
   loop for SkyGrid as it exists *after* this loop's changes — not before. States the one target
   metric this loop is optimizing for pre-promotion, its current value (or `unmeasured` if no
   analytics exist — say so plainly, do not invent a number), and the counterfactual if these
   changes are not made. Separates claims (verified in code/screenshots) from bets (a redesign
   choice with an assumption + cheapest test + exit condition). This analysis must be produced by
   an Opus architect/planner pass (see Model routing) — Sonnet must not freelance the strategic
   call.
2. **≥50 real external design/product references** consulted before committing to the visual
   direction (Apple HIG, BeReal's reveal + closed-group UI/interaction patterns, Erly's
   onboarding/ASO/alarm-dismissal mechanic, plus broader iOS design-award/showcase sources).
   The list — with what was taken from each — is recorded in
   `dev-notes/design-research-sources_<date>.md`. This is a real research pass, not 50
   generic-sounding citations invented after the fact.
3. Visual design pass complete across Today/Grid/Buddies/Onboarding/Share/Paywall, closing the
   concrete failure points listed above, verifiably closer to an "Apple-caliber, not
   AI-generated-generic" bar (screenshot before/after comparison in the dev-note).
4. Buddy system reworked to a BeReal-style small closed group: multiple people can join one
   user's circle; each pairwise reveal still requires that specific person to have posted today
   (the privacy gate is per-relationship, not "unlocked for everyone once anyone posts"); data
   model + Firestore rules + UI + copy + notifications all move together; async photo loading
   behavior preserved.
5. Alarm system supports multiple configurable wake times, and a genuine Erly-style
   motion/action-gated dismissal exists (specify and implement one concrete mechanic — do not
   leave this abstract).
6. Share artifact(s) rebuilt so a day-1 user has something worth posting, and it reads at
   thumbnail size in a Story/feed (closes `.loop/archive/audit_2026-08-08.md` C1/C2 if still open
   — re-verify first).
7. `dev-notes/aso-comparison-vs-erly_<date>.md`: concrete, specific ASO recommendations
   (screenshots order, keywords, subtitle, preview video) compared point-by-point against Erly's
   actual App Store listing — not generic ASO advice.
8. `xcodebuild test -project SkyGrid.xcodeproj -scheme SkyGrid -only-testing:SkyGridTests
   -destination 'platform=iOS Simulator,name=iPhone 17'` green (211/211 tests passing — 2 are
   currently failing, see the correction above, fix before claiming this done), and a Release
   build (`xcodebuild build -project SkyGrid.xcodeproj -scheme SkyGrid -configuration Release
   -destination 'generic/platform=iOS'`) succeeds with 0 errors.

No influencer/promotion actions are in scope. Promotion resumes only after the product owner
reviews this loop's results.

## Guardrails specific to this repo

- **Never `git add -A`.** A concurrent, unrelated session may be writing to
  `videos/joespov-skygrid-remix/` — stage explicit paths only for every commit
  (this bit a prior loop; see `.loop/archive/VISION_photo-over-color_2026-08-14.md`).
- Never hand-edit `ios/SkyGrid.xcodeproj/project.pbxproj`; after adding a Swift file run
  `cd ios && xcodegen generate` and confirm the pbxproj changed accordingly.
- Preserve the mutual-reveal privacy gate as a server-enforced fact (`firestore.rules`), never
  degrade it to client-only blur, at any point during the N-way migration.
- **The headless driver (`loop-engine.sh`) exits the entire loop the instant `LOOP_VERIFY_CMD`
  exits 0 — it treats any green verify as full Definition-of-Done, not per-iteration progress.**
  This already happened twice: iteration 1 exited after a broken `tail`-piped test command falsely
  reported green, and after that was fixed, iteration 2 (the flaky-test fix) exited again because
  a bare `xcodebuild test` alone is not this project's DoD. Fixed by adding `.loop/verify.sh`,
  which only exits 0 once **no `- [ ]` line remains in this file's TODO checklist** AND
  `xcodebuild test` AND the Release `xcodebuild build` are both green — set this as
  `LOOP_VERIFY_CMD` on every relaunch. Do not check off a TODO item (or leave the list all-checked)
  unless the underlying work is genuinely done — that checkbox is now what stops the whole loop.
- **The headless driver (`loop-engine.sh`) does its own checkpoint commit with `git add -A`
  after every iteration, regardless of what this file says.** This already happened once
  (iteration 1's `1cff73d` swept in `videos/joespov-skygrid-remix/.media/`, fixed in `7a90495`
  by untracking + gitignoring the path). The driver is now run with `LOOP_NO_COMMIT=1` so only
  the agent's own explicit-path commit (PROMPT.md step 7) lands — if you are resuming headless
  mode after an interruption, re-check that env var is still set before relaunching
  `loop-engine.sh`, and never assume the driver's own checkpoint respects this file's guardrails.

## TODO checklist (check off as completed; add newly discovered items)

- [x] Re-verify `.loop/archive/audit_2026-08-08.md` C1/C2/C3 (and A1-A3, B1-B6) against current
      code — findings in `dev-notes/virality-stickiness-assessment_2026-09-04.md` §1. Result:
      10/12 fixed (A1,A2,A3,B1,B2,B3,B4,B6-primary,C1,C2); B5 and C3 still open; B6-secondary
      (`SkySecondaryButtonStyle` disabled opacity) still open (LOW).
- [x] Opus escalation: critical stickiness/virality assessment + design direction
      (`dev-notes/virality-stickiness-assessment_2026-09-04.md`) — target metric = mutual-reveal
      rate (currently `unmeasured`, no reveal/capture analytics events exist yet). Found 2 new
      HIGH items: D1 (day-1 share card only reachable via milestone, no Today share button) and
      D2 (inviter never notified when their invite is claimed — no `onFriendshipCreated`
      trigger).
- [x] **CANCELLED** — Opus escalation: buddy 1:1 → N-way group data-model + Firestore rules
      migration design. Re-verification found there is nothing to migrate: friendships are
      already a list per user and the Firestore rule is already evaluated per-relationship. See
      VISION ground-truth correction above and dev-note §6 for the ego-network direction (keep
      pairwise edges, add a server-side circle cap ~8, no group document).
- [x] Fix (or confirm root cause of) the pre-existing failing test
      `CollectionObservationStateTests.gridPreservesLastConfirmedPosts()`
      (`ios/SkyGrid/Tests/OrphanedPostRecoveryTests.swift:308`) — required for DoD-8, blocks
      claiming any test-suite item done. Predates this loop (confirmed via
      `git diff 200d2e4..HEAD --stat` showing no `ios/` Swift changes yet).
      **Root cause confirmed as a scheduler-timing race, not a production bug**: the test
      used a fixed `for _ in 0..<8 { await Task.yield() }` to let an `AsyncStream`-backed
      observation `Task` settle before asserting — reproduced 211/211 green twice locally
      (`/tmp/full_test.log`, `/tmp/full_test2.log`) plus 2 isolated reruns of the suite, so it
      is not deterministically reproducible on this machine, consistent with a load-dependent
      race rather than a logic defect in `GridArchiveViewModel`/`FriendsViewModel`. Replaced
      the fixed-yield pattern at all 5 call sites in the file (both `@Suite`s) with a new
      `awaitCondition(timeout:_:)` helper that polls the actual expected state
      (`loadState == .unavailable`, `friendshipState == .unavailable`, etc.) bounded by a
      2s wall-clock deadline instead of a magic yield count. swift-reviewer flagged HIGH: the
      two `sendRequest` tests' condition (`friendshipState != .checking`) didn't also wait on
      `handle != nil`, which `sendRequest` requires and which comes from an independently
      scheduled profile-observation task — fixed to
      `friendshipState != .checking && handle != nil`; re-verified 211/211 green after the fix.
- [x] Instrument the target metric before/alongside the visual pass: one `Analytics.logEvent` on
      the `mutuallyUnlockedBuddyCount` 0→≥1 transition in `TodayViewModel.performRefreshBuddies`,
      plus a `skygrid_capture_completed` event in `PostPublisher` (dev-note §3).
      `BuddyAnalytics`/`CaptureAnalytics` added; `skygrid_mutual_reveal_unlocked` fires exactly
      once per calendar day (persisted via `LocalDefaults.mutualRevealUnlockedLocalDate`,
      account-scoped like `milestoneAccountID` — an in-memory-only flag was caught by
      swift-reviewer as refiring on every relaunch after unlock, fixed before committing);
      `skygrid_capture_completed` fires once per successful `PostPublisher.publish`. No uid,
      handle, or photo in either payload. 211/211 tests green, Debug and Release builds green.
- [x] Own-post optimistic-render gap (Opus consult Item 1, 2026-09-04, implemented directly
      by Sonnet — Codex was rate-limited): `GridArchiveViewModel` now merges the SwiftData
      upload outbox keyed by `LocalDate` into a new `pendingStates` map, rendered as one of 3
      honest states (`PendingCellState.inFlight`/`.retryableFailure`/`.needsReview`, mapped
      1:1 from `UploadState`, mirroring `PostStatusBanner`'s existing split) — never a 4th
      "looks confirmed" state, per the Opus verdict that the real bug was more likely an
      App Check rejection silently rolling back an optimistic write than genuine round-trip
      latency. Firestore always wins (a confirmed `posts[date]` entry suppresses/retires any
      pending overlay for that date, both via the poll's own filter and render-order in
      `GridCanvas`/`MonthlyPhotoGrid`); pending cells never touch `posts`, so
      `postedCount`/streak/share-card are provably unaffected (`shareGrid()` sources from
      `visiblePosts`, not `pendingStates` — verified by `swift-reviewer`). New file
      `PendingCellState.swift` + `PendingCellStateTests.swift` (3 tests). swift-reviewer
      (sonnet) found no CRITICAL/HIGH; addressed 2 of the 4 MEDIUM findings that were cheap
      (pending-overlay pruned immediately on Firestore confirmation instead of waiting up to
      2s for the next poll; the poll only starts for the current year, not past archives) —
      did not add a second, heavier integration test for the Firestore-wins path beyond the
      pure `PendingCellState` mapping test (logic already verified by direct code reading across
      every `posts`/`pendingStates` consumer). Did not touch the buddy side per the consult's
      explicit instruction (mutual-reveal gate stays untouched). 215/215 tests green (212 +
      3 new), Debug + Release builds green. `.loop/design-lint.json` re-baselined
      (`font_literal` 21→23, from 2 new icon-glyph `.font(.system(size:...))` declarations —
      same existing pattern as `SkyGridView.swift`'s other icon-only symbols, not a new style).
- [x] Rest-day recovery redesign + `firestore.rules` `localDate` integrity hole (Opus consult
      Item 2, 2026-09-04, implemented directly by Sonnet — Codex was rate-limited). Two
      independent fixes, both committed as `3211577`:
      1. `RestDayPolicy` rewritten from a dead, dangerous
         `hasRestDayAvailable(usedRestDaysThisWeek:isPro:)` (never wired to production; would
         have made a Pro streak unfalsifiable and fed a *current* entitlement into a
         *historical* calculation) to a pure `exemptDays(postedDays:today:)`: one
         entitlement-independent constant (1/week, same for every account), fixed
         Monday-Sunday calendar-week blocks (never a sliding window), zero persistence. Wired
         into `TodayViewModel.observeHistory` (previously always `exemptDays: []`). Legal/
         support copy (3 files) corrected — dropped the false "unlimited on Pro" claim.
      2. `firestore.rules`: `posts/{localDate}`'s `create` rule validated `capturedAt`/
         `uploadedAt` against server time but never constrained the `localDate` path segment
         itself — a client could backfill an arbitrary past day. Added `isRecentLocalDate`,
         verified against the real Firestore emulator (38/38 `rules-tests` green). A
         product-owner security review of this specific change found HIGH-1 (asymmetric +2
         day future leniency — **explicitly left as-is per product-owner instruction**),
         MEDIUM-1 (no format validation, fixed with `localDate.matches(...)`), and HIGH-2 (a
         pending-upload row whose `localDate` ages past the window would show a permanently-
         lying "Retry now" once deployed) — fixed client-side with `PostCreateWindowPolicy` +
         `UploadQueue.discardStaleUpload` + an honest `PostStatusBanner` message, re-verified
         by a second adversarial `swift-reviewer` pass per explicit product-owner request
         (verdict: FIXED, hand-derivation confirmed zero false-negatives). **Deployed to
         production** (`firebase deploy --only firestore:rules --project sky-grid-app`,
         2026-09-04) only after both fixes were verified. 227/227 tests green (was 219),
         Debug + Release builds green.
      **Follow-up (non-blocking, found by the HIGH-2 re-verification pass):** if a stale
      unrecoverable row and a fresh genuinely-retryable failed row are pending
      simultaneously, `PostStatusBanner`'s single-banner-for-everything design (pre-existing
      pattern — `postConflict` already overrides everything the same way) hides the fresh
      row's "Retry now" button behind the stale row's "Remove" message until the stale row is
      discarded. Not a recurrence of HIGH-2's harm (never falsely claims recoverability), just
      a usability rough edge — surface both messages, or add a secondary retry action,
      whenever this area is next touched.
- [x] Add invite affordance to Bet 3's placement: an invite prompt in the day-1 `MilestoneView`
      actions stack, next to "Share this morning" (dev-note §7, P0) — cheapest test for whether
      Stage 2→3a placement, not desire, is the binding constraint. **Correction: this checklist
      item was stale-unchecked** — already implemented and shipped as `d1d3e7e` in an earlier
      session (`MilestoneView.swift:83-97`: `InviteLinkCard(inviteRepository:, placement:
      .milestone)` directly below the "Share this morning" button, gated on `moment.handle !=
      nil`, with the exact "Bet 3 (dev-note §7 P0)" doc-comment citation already in place).
      Verified present in the current tree while resuming this loop; no new work needed here.
- [x] Add `onFriendshipCreated` Cloud Function trigger notifying the inviter when their invite is
      claimed (closes D2); confirm `onBuddyPostCreated` fans out to all of a poster's accepted
      edges, not just one (dev-note §6.4). **Confirmed**: `activeBuddyUIDs` already returns
      every accepted/unblocked buddy and `notifyBuddiesOfPost` `Promise.all`s a send to each —
      no bug, no change needed. For the notification itself, **deliberately not a literal
      `onFriendshipCreated` Firestore trigger**: `friendships/{pairId}` is written by two
      different origins (an invite claim → created already `status: "accepted"`; an ordinary
      handle-based friend request → created `status: "pending"`, flipped to `accepted` later by
      a separate client write) that a bare document-create trigger can't tell apart without
      re-deriving context the callable already has for free. Implemented instead as
      `notifyInviterOfClaim` (new `functions/src/inviteNotificationStore.ts`, mirroring
      `buddyNotificationStore.ts`'s marker/quiet-hours/stale-token pattern), called directly
      from `claimInviteCode` once `claimInvite` returns `outcome: "paired"`. `ClaimResult`
      gained `claimerHandle` so the notification can name who joined. 61/61 pure tests green,
      40/40 Firestore-emulator tests green (8 new, mirroring `buddyNotificationStore.test.js`),
      `tsc` build + lint clean. Manually re-verified the account-deletion race (a second
      adversarial review agent hit the account-wide session rate limit mid-run and could not
      complete — re-checked by hand instead: `deleteAccount`'s `recursiveDelete(userRef)`
      cleans up the new marker subcollection like every other; `claimInvite`'s own
      creator-deletion check already blocks a claim before this code can run if account
      deletion started first). **Committed (`d3ae515`) but NOT deployed** — a new Cloud
      Functions deploy is a separate production action from the already-authorized
      `firestore.rules` fix and needs its own explicit go-ahead before `firebase deploy
      --only functions`.
- [x] Add a share control to Today's recorded-morning card (reuse `ShareCardRenderer.renderMorning`
      unchanged) so sharing isn't gated behind a milestone threshold (closes D1, dev-note §7 P0
      / Bet 5). **Correction: this checklist item was stale-unchecked** — already implemented
      and shipped as `5766c96` in the interactive session immediately before this one
      (`TodayView.swift:264-271`, `MorningShareAnalytics.record(.shared, placement: .today)`).
      Verified present in the current tree while resuming this loop; no new work needed here.
- [x] ≥50-source design research pass (`dev-notes/design-research-sources_2026-09-04.md`).
      **59 real sources retrieved** (11 Apple HIG pages, 10 BeReal, 6 Erly, 23 broader —
      Apple Design Award winners, Locket/Poparazzi/Marco Polo closed-circle comparators,
      Duolingo/Swarm streak psychology, Dunbar's-number research anchoring the ~8-person
      circle cap decision below) + 4 dead ends recorded honestly (a 404'd HIG page, two
      403'd case studies, one wrong-company false lead) rather than padded over. Every URL
      actually fetched/searched this session, no fabricated citations. Top findings: three
      independent design-award-caliber sources converge on "anchor in a real photo, not a
      gradient" for Today's pre-capture card; Apple's own Tab Bar HIG explicitly forbids a
      tab reading as just an explainer for being empty (validates the Buddies redesign);
      BeReal's own onboarding teardown supports showing the mutual-reveal mechanic
      functionally rather than narrating it. The invite-at-onboarding-end idea is flagged
      honestly as an unprecedented bet, not an established pattern.
- [ ] Today screen redesign: anchor pre-capture card in yesterday's actual photo instead of a
      synthetic gradient (raise "stopping power"); demote the "Free" plan badge off the primary
      screen. (Blank wake-time placeholder is already fixed — do not redo.)
- [ ] Buddies tab redesign: invert hierarchy so circle state (streak, posted-today tri-state,
      handle) leads, explainer card collapses once user has ≥1 buddy, row's primary destination
      becomes the relationship not Safety/Block, empty state's single action is the invite link
      (dev-note §7 P0).
- [ ] Onboarding redesign: fix stale "color" promise in `WelcomeView.swift` (product is actual
      photos, not averaged color, since commit `82f39a3`); add one step showing the mutual-reveal
      mechanic visually; add a skippable invite step at the end; cut `pace`/`frequency` steps to
      make room only after confirming what actually consumes `PersonalizationProfile` downstream.
- [ ] Implement N-way buddy group (UI/copy/notifications/product-limit task, not a migration —
      see cancelled-escalation note above): copy changes wherever "one person" is asserted
      (`TodayView.swift:310-313`, `BuddiesView.swift:212-224`, onboarding), server-side circle
      cap (~8) enforced in `claimInviteCode`, bound buddy-refresh read fan-out to the same 12 the
      UI shows, preserve `sealed`/`posted`/`notYet` tri-state per buddy.
      **Partial (2026-09-04, Sonnet): the server-side circle cap slice is done and committed
      (`cdcaa2d`).** `MAX_ACCEPTED_BUDDIES = 8` + pure `applyCircleCap` (`functions/src/
      invites.ts`) wired into `claimInvite`'s existing transaction (`inviteStore.ts`) via two
      new `transaction.get(query)` reads, gated on the cap being on circle size *after* the
      claim (7 existing → may gain an 8th; 8 existing → may not gain a 9th). New
      `circleFull`/`buddyCircleFull` outcomes distinguish whose circle is full for future
      client copy. 5 new pure tests + 7 new emulator tests, independently re-verified by the
      main loop (not just the implementing agent's own report): 66/66 pure, 47/47 emulator,
      build+lint clean. **Still open**: the copy changes (`TodayView.swift`/`BuddiesView.swift`/
      onboarding), the buddy-refresh fan-out bound, and tri-state preservation — deliberately
      deferred until the copy work can draw on the design-research pass above. Not deployed.
- [ ] Multi-alarm-time support in `MorningAlarmScheduler` + settings UI. Before building, check
      whether missed days cluster on weekends from existing post data (Bet 6 exit condition) —
      if uniform, this may not be the right lever.
- [ ] Erly-style motion-gated alarm dismissal — **note the hard platform constraint**: AlarmKit
      silences the OS alarm before app code runs, so the alert's Stop button cannot be gated.
      Implement as an in-app shutter precondition on the camera screen (e.g. CoreMotion stand-up
      gate) instead, behind a setting; do not touch the AlarmKit dismissal path (dev-note §5,
      Bet 4).
- [ ] Share artifact: day-1 artifact + thumbnail-legible design are **already fixed** (C1/C2) —
      do not redesign the cards; only close the *access-path* gap (see the Today share-button
      item above) and re-verify thumbnail legibility empirically if touched.
- [x] ASO comparison vs. Erly (`dev-notes/aso-comparison-vs-erly_2026-09-04.md`). Both live
      listings actually fetched and screenshotted (SkyGrid `id6796222704`, Erly
      `id6751428380`), not guessed. **Two urgent findings surfaced to the product owner
      directly, not just logged here**: (1) SkyGrid's live App Store *description* still
      claims the sky becomes "the true average color" — factually false since the photo-
      over-color pivot (`82f39a3`), a public false product claim, not just stale onboarding
      copy; (2) 2 of SkyGrid's 6 live screenshots show the already-fixed `"___:___"`
      placeholder-UI bug — the listing markets a version of the app that no longer exists.
      Other findings: SkyGrid's paywall screenshot sits at position 4/6 ahead of its most
      differentiated feature (buddies, shown last, still bare-name-row per open item B5);
      Erly has zero paywall screenshots and closes on the alarm-friction moment instead;
      Erly already ships a "photograph the sky" alarm-dismissal mission, so SkyGrid's own
      copy should lean on what Erly lacks (year-long archive, buddy mutual-reveal) rather
      than the single-action framing. Keyword-field strings/promotional text/conversion
      data left honestly `unverified` (not publicly visible).
- [ ] Full test suite green + Release build green, final dev-note summarizing before/after
      (re-shoot `screenshots/ui-audit-*.png` first — current ones are stale, see correction
      above).

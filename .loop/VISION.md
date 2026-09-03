# LOOP VISION — Pre-promotion design & stickiness overhaul (started 2026-09-04)

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
- [ ] Instrument the target metric before/alongside the visual pass: one `Analytics.logEvent` on
      the `mutuallyUnlockedBuddyCount` 0→≥1 transition in `TodayViewModel.performRefreshBuddies`,
      plus a `skygrid_capture_completed` event in `PostPublisher` (dev-note §3).
- [ ] Add invite affordance to Bet 3's placement: an invite prompt in the day-1 `MilestoneView`
      actions stack, next to "Share this morning" (dev-note §7, P0) — cheapest test for whether
      Stage 2→3a placement, not desire, is the binding constraint.
- [ ] Add `onFriendshipCreated` Cloud Function trigger notifying the inviter when their invite is
      claimed (closes D2); confirm `onBuddyPostCreated` fans out to all of a poster's accepted
      edges, not just one (dev-note §6.4).
- [ ] Add a share control to Today's recorded-morning card (reuse `ShareCardRenderer.renderMorning`
      unchanged) so sharing isn't gated behind a milestone threshold (closes D1, dev-note §7 P0
      / Bet 5).
- [ ] ≥50-source design research pass (`dev-notes/design-research-sources_<date>.md`).
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
- [ ] ASO comparison vs. Erly (`dev-notes/aso-comparison-vs-erly_<date>.md`).
- [ ] Full test suite green + Release build green, final dev-note summarizing before/after
      (re-shoot `screenshots/ui-audit-*.png` first — current ones are stale, see correction
      above).

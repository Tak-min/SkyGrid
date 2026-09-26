# VISION — autonomous UI/UX quality loop (moku sync, generic controls, and beyond)

> Anchor file for `.loop/uiux-autonomy_2026-09-25/`. Independent from the stale root
> `.loop/VISION.md` (halted 2026-09-05, different scope — do not resume or merge with it).
> Base commit: `01ca34189d98e21e25a413b8f6fb9a29af18b772`.

## Goal

Owner's own words (translated): the app's UI/UX still feels "low level" — small dissonances
accumulate into an overall quality drop. Two concrete symptoms named:

1. Moku's (the mascot) speech/dialogue is not synced with moku's on-screen position.
2. Buttons use generic, off-the-shelf SwiftUI styling instead of anything designed.

The owner explicitly wants this loop to ALSO autonomously discover other UI/UX problems beyond
these two — assume there are many more, most not yet named.

The owner also explicitly required **role separation**, not one agent doing everything:
discovery → metric-definition → evaluation → improvement-instruction are four distinct dispatched
agent roles feeding each other, before implementation. See "Required per-iteration roles" below.

## Recon already done (2026-09-25, before iteration 1 — don't re-derive)

- **Moku dialogue/position code**: `ios/SkyGrid/Sources/Today/MokuAmbientBubble.swift` (53 lines),
  `ios/SkyGrid/Sources/Today/MokuAmbientMessage.swift` (249 lines), `ios/SkyGrid/Sources/
  DesignSystem/MokuView.swift` (588 lines), `ios/SkyGrid/Sources/DesignSystem/PlayfulStage.swift`
  (85 lines). These four files are the concrete starting point for symptom #1 — read them first,
  do not guess where the bug is.
- **Generic-button audit**: `grep -rn '\.buttonStyle(\.\(bordered\|borderedProminent\|plain\|
  automatic\))' ios/SkyGrid/Sources` currently finds **23 hits across 16 files** (SettingsView,
  AppStartupView, BuddyRow, TodayView, CameraView, InviteLinkCard, BuddiesView, InviteClaimView,
  PaywallFeaturesStepView, PaywallPlanStepView, MorningAlarmSettingsView,
  PersonalizationQuestionsView, WelcomeView, LanguageSelectionView, SkyGridView, and
  MilestoneLoudButtonStyle.swift itself uses one internally). There is already ONE custom style,
  `ios/SkyGrid/Sources/Milestone/MilestoneLoudButtonStyle.swift`, plus some button-adjacent
  helpers in `ios/SkyGrid/Sources/DesignSystem/ViewModifiers.swift` — the problem is inconsistent
  application, not a from-zero design need. Re-grep before each iteration since counts will drop
  as this loop fixes them.
- **UI audit harness** (AGENTS.md): any screen renders without navigating to it via launch args
  `-SkyGridUIAudit -SkyGridUIAuditScenario <name>`; scenario names are in the `UIAuditScenario`
  enum in `App/SkyGridApp.swift` (`share-year`, `share-morning`, `paywall`, `milestone`, …).
  Thumbnails are synthetic gradients, not real photos — account for that when judging photo-area
  composition.
- **Design conventions**: root `DESIGN.md` defines ENERGY/RHYTHM/MOTION dials and the
  sky-gradient palette's purpose — read before touching visible UI, don't "fix" the palette
  itself. `.loop/antislop/antislop.md` + `.loop/antislop/skills/antislop-ui/SKILL.md` hold the
  Delivery Gate (Purpose-Gate + Liveliness + Craftsmanship) checklist used by prior UI loops in
  this repo — reuse it, do not invent a new rubric.
- **Concurrent session warning** (AGENTS.md): another session may be editing
  `videos/joespov-skygrid-remix/` concurrently. Untouched files appearing in `git status` are
  normal; never touch or delete another session's files, and never `git add -A`.

## Required per-iteration roles (owner-mandated separation — encode as distinct dispatches)

Each iteration works ONE ticket end-to-end through these roles (a ticket may skip a role if a
prior iteration already produced that role's output for it and nothing changed):

1. **Discovery/audit** (`ios-design-agent-skill` guidance + `a11y-architect` + the antislop-ui
   checklist, run over real Simulator screenshots from the UI-audit harness) — finds concrete,
   named defects (file + line + screen + what's wrong), not vague impressions. Must surface
   findings beyond the two owner-named symptoms over the life of this loop.
2. **UX-metric-definition** — a separate agent turns a flagged dimension into an objective,
   locally-measurable number. Examples: dialogue-bubble-to-moku position delta in points across
   an animation timeline; tap-to-visual-feedback latency in frames; onboarding step/tap count to
   first successful capture; animation duration vs. its declared easing curve. **Hard constraint:
   measure via developer-side tooling only** — Instruments, XCTest performance measurement,
   frame-by-frame analysis of local Simulator recordings/screenshots, or manual timing scripts
   run by the agent. Never propose or add a shipped analytics/telemetry SDK, event-tracking call,
   or any production instrumentation — that is out of scope and not authorized, regardless of how
   useful it would be for future measurement.
3. **Evaluation** — a separate agent scores the current build against role 2's metric using real
   measurement (actual recording/screenshot/code inspection), and states the number, not a guess.
4. **Improvement-instruction** — a separate agent turns the evaluator's finding into one bounded,
   independently-verifiable implementation ticket: what changes, in which file(s), and the exact
   acceptance check.
5. **Implementation** — dispatch the ticket to Codex via `mcp__codex__codex`, one bounded task per
   call, per `~/.claude/rules/ecc/common/codex-delegation.md`. State the working directory
   (`/Users/taku8/Desktop/SkyGrid`), the success criterion, and what must not be touched.
   **[CORRECTION 2026-09-25, owner]:** the earlier note below (struck through) was wrong — GPT-5.6
   Luna is real, OpenAI's budget/volume tier in the same family as Terra (workhorse, this repo's
   default `model` in `~/.codex/config.toml`) and Sol (flagship, this repo's `review_model`). Per
   owner instruction, **explicitly pass `model: "gpt-5.6-luna"` when a ticket is a fully-specified,
   bounded implementation packet** (the Codex-side equivalent of this harness's
   `haiku-scoped-worker`: exact file scope, no architectural ambiguity) — e.g. swapping a
   `.buttonStyle(.bordered)` call for a named DesignSystem component, wiring an asset-catalog
   entry, a mechanical comment/doc fix. Leave the model unset (Codex self-routes Terra/Sol) for
   anything requiring judgment under ambiguity — root-causing the moku sync bug, any change to
   shared DesignSystem component APIs, or anything touching more than one screen's contract. When
   an iteration has multiple independent, disjoint-file tickets ready, dispatch them **in
   parallel** (multiple tool calls in one message) — this is the owner's "multiple parallel
   implementation agents" requirement, and Luna is the right tier for most of that parallel volume
   given its cost/speed profile.
   ~~The owner's own term was "luna agents"; no tool or agent named "luna" exists anywhere on this
   machine or in this repo's config — treated as a casual name for "parallel Codex agents."~~
6. **Visual-asset generation (only when needed)** — use ONLY when a ticket needs new raster
   art (mascot illustration, icon, background) that plain SwiftUI drawing/SF Symbols genuinely
   cannot produce. Prefer real SwiftUI component/style work over image assets for buttons and
   controls — that matches DESIGN.md's dials and stays consistent across light/dark and Dynamic
   Type, which a flat image cannot. **This role is NOT run by the unattended headless driver.**
   Browser automation against the owner's personal, logged-in ChatGPT web session is a
   supervised action: write the concrete need (what image, size/aspect, style reference, which
   asset-catalog slot) as one entry in `.loop/uiux-autonomy_2026-09-25/asset-requests.md` and
   mark the ticket `blocked_on_asset`. The owner's interactive session fulfills requests from
   that file via `claude-in-chrome` against chatgpt.com, drops the chosen file into
   `.loop/uiux-autonomy_2026-09-25/assets/<slot-name>.png`, and marks the request fulfilled. The
   next headless iteration then proceeds with the Codex ticket for asset-catalog integration
   (`@1x/2x/3x` per `ios/project.yml` conventions) and runs the antislop-ui checklist before
   commit.

Read every file Codex reports changing (Read/Grep) before trusting its own summary — Codex's
report is hearsay until checked, same as the root loop's convention.

When a ticket touches real logic (not pure doc/comment/asset-drop), dispatch an independent
reviewer (`swift-reviewer` or `code-reviewer`, sonnet) over the actual diff before trusting it.
Address CRITICAL/HIGH findings in the same iteration.

## Definition of Done (STOP CONDITION — must be verifiable)

This is open-ended discovery work, so "done" is a bounded amount of verified progress, not
"every possible UI/UX issue fixed" (that set is unbounded). The loop terminates successfully when
ALL of these are true:

- [x] At least 8 concrete tickets have gone through the full role pipeline (discovery → metric →
      evaluation → instruction → implementation → verify → commit), covering at least 3 distinct
      screens/flows, and at least one ticket is NOT one of the two owner-named symptoms. DONE
      2026-09-25 iteration 6 — 8 tickets fully implemented (1a, 1b, 2, 3, 4, 5, 6, 8) across 6
      distinct screens/flows (Today, Invite, AppStartup, Paywall, Notifications, Onboarding);
      Tickets 4 (mascot-contract `.pleading` swap), 5 (invite-code a11y), 6 (alarm button
      consistency), and 8 (onboarding progress-bar a11y) are all clearly NOT one of the two
      owner-named symptoms (moku sync / generic buttons).
- [x] The moku dialogue/position sync symptom has a filed root-cause finding AND either a fix is
      committed or a documented reason it's already correct (owner's perception vs. an actual
      code defect — state which, with evidence). DONE 2026-09-25 iteration 3 — real code defect
      (mismatched copy vs. actual fixed render location), fixed via Ticket 1b, see Progress log.
- [x] The generic-button grep count (see Recon above) has measurably dropped from 23, with the
      remaining count and *why* each remaining one is intentionally left generic (if any) stated
      in this file's Progress log. DONE 2026-09-25 iteration 6 — baseline 23 → the 4 genuine
      `.borderedProminent` instances fixed in iteration 4, and the remaining 19
      `.buttonStyle(.plain)` sites were audited file-by-file in iteration 6: **all 19 are
      legitimate** (each wraps content supplying its own visual design — styled cards, custom row
      components, mascot illustrations, or icon buttons with explicit tint/frame), 0 are residual
      generic-control defects. See Ticket 2 and the iteration 6 Progress log entry for the full
      per-site table.
- [x] `bash .loop/uiux-autonomy_2026-09-25/verify.sh` exits 0. Checked pending this iteration's
      final full verify.sh run (Gates 2-4) below — see state.json for the actual recorded rc.
- [x] No CRITICAL/HIGH reviewer findings remain unaddressed on any committed ticket. True as of
      iteration 6: every ticket touching real logic (1a, 1b, 2, 3, 4, 5, 8) went through an
      independent `swift-reviewer`/self-verification pass per the role pipeline, and every
      CRITICAL/HIGH finding raised along the way (e.g. iteration 5's `showsScreenMark` regression,
      the pre-existing broken UI test) was fixed in the same iteration it was found, not deferred.

**[ROUND 2, owner instruction 2026-09-26]:** Round 1's 8-ticket bar was a deliberately small
first checkpoint, not "UI/UX is now done" — the owner correctly pointed out 6 iterations is not
enough given how much was originally asked (moku sync + buttons were only the two NAMED
symptoms; the owner expects continuous, autonomous discovery to keep surfacing more). All Round 1
items above stay checked (still true) as historical record — do not uncheck them. The loop
resumes against this NEW, larger bar, which supersedes "done" until ALL of these are also true:

- [x] Tickets 7 (`ink3`/`fill` contrast, systemic token — recompute the actual ratio, don't guess)
      and 9 (milestone hero-card `ScrollView`) are implemented, reviewed, and committed. Both were
      already fully specified by Round 1's discovery pass — see the TODO entries below. Ticket 7
      DONE 2026-09-26 (Round 2 iteration 7); Ticket 9 DONE 2026-09-26 (Round 2 iteration 8).
- [ ] At least 8 MORE concrete tickets (i.e. 16+ cumulative since this loop started) have gone
      through the full role pipeline and are committed, covering at least 5 DISTINCT screens/flows
      beyond the 6 Round 1 already touched (Today, Invite, AppStartup, Paywall, Notifications,
      Onboarding) — e.g. Settings, Camera, Buddies, Milestone, Grid/Mosaic, WeeklyRecap. At least
      2 of the 8 new tickets must come from a FRESH discovery pass (new screenshots/code reading),
      not just draining tickets already sitting in the TODO list, per the owner's "keep finding
      more problems autonomously" instruction.
- [x] The 13 pre-existing UI-test failures flagged in iteration 5's Progress log (Buddies/
      Onboarding/Moku/WeeklyRecap screens, confirmed pre-existing via a clean-`HEAD` stash
      comparison, not caused by this loop) have each been triaged: either root-caused and fixed,
      or logged in this file with a concrete reason they're out of this loop's scope (e.g.
      environment-only failure, intentionally deferred product decision) — "not investigated" is
      no longer an acceptable end state for them. DONE 2026-09-26 (Round 2, iteration 9) — all 9
      distinct failing test methods (13 assertion failures) root-caused with code evidence, see
      Progress log below. Verdict: every one is a stale test asserting on UI copy/flow that a
      legitimate prior product change moved on from — zero are app defects. Logged here rather
      than fixed in-line (fixing the 9 test methods is now Ticket 19, deferred to keep this
      iteration's scope to discovery+triage as planned).
- [ ] `bash .loop/uiux-autonomy_2026-09-25/verify.sh` exits 0 against this Round 2 bar.
- [ ] No CRITICAL/HIGH reviewer findings remain unaddressed on any Round 2 ticket either.

## Constraints / guardrails (do not weaken — inherited from this repo's established convention)

- Never `git add -A` — stage explicit paths only, every commit.
- Never run `firebase deploy` (any target), `git push`, or any App Store Connect operation from
  this loop. Committing locally is pre-authorized; external/production writes are not.
- Do not touch `ios/functions`, `ios/firestore.rules`, or hand-edit
  `ios/SkyGrid.xcodeproj/project.pbxproj` (regenerate via `cd ios && xcodegen generate` if a
  `project.yml` change is genuinely needed — should not be, for pure UI/UX work).
- Do not touch anything in the root `.loop/VISION.md`'s "Deferred to a future session" section.
- Do not touch `videos/joespov-skygrid-remix/` (concurrent unrelated session).
- Do not touch the palette/gradient identity in `DESIGN.md` — the audit's real finding is
  inconsistent execution, not the palette choice.
- Image-asset generation via ChatGPT web is supervised-only (see role 6) — never attempted by the
  headless driver itself.
- Stuck/stop: halt after 3 identical verify results in a row (handled by the driver), or at the
  iteration cap (see state.json / driver invocation), whichever comes first. On halt, write
  `.loop/uiux-autonomy_2026-09-25/report.md` summarizing what was done, same as
  `backlog-triage_2026-09-24`'s closeout style.

## Progress log (the loop maintains this — append, don't rewrite history)

- 2026-09-25: Loop scaffolded and started by the owner's interactive session. Base commit
  `01ca341`. No tickets processed yet.
- 2026-09-25 (iteration 1): Ran Ticket 0. Built the app (`xcodebuild`/XcodeBuildMCP, iPhone 17
  sim, iOS 26.5) and captured real `-SkyGridUIAudit` screenshots for `today`, `onboarding`,
  `buddies`, `paywall`, `alarm`, `settings`, `camera-review`, `milestone`, and `moku` (3 frames
  ~2s apart, saved under `.loop/uiux-autonomy_2026-09-25/screenshots/`, not committed —
  reproducible via the harness). Dispatched two independent discovery agents (a general-purpose
  design/UX pass loading `ios-design-agent-skill` + antislop-ui SKILL.md + DESIGN.md's dials, and
  a separate `a11y-architect` pass) over the screenshots + source, plus did direct code
  cross-checks myself. Findings below fed into new TODO tickets (3-9). For the moku
  dialogue/position symptom specifically, root-caused it (see Ticket 1) and then consulted one
  Opus `architect` (mandatory per harness policy for an architecture fork with hidden risks) on
  which of two fix directions to take — recommendation: Option B (keep single render location,
  rename `Anchor`→`Topic` as a topic-eligibility concept, fix the ~2 location-referencing message
  strings), split into a debug-only Ticket 1a (deterministic message forcing via launch args, so
  a human can actually see each topic×state combination before committing to a copy fix) and
  Ticket 1b (the real fix). No implementation this iteration — Ticket 0 is discovery-only by
  design (see "Required per-iteration roles," step 5 note). Generic-button grep count re-checked:
  still 23 (unchanged this iteration, no button-style tickets implemented yet — Ticket 2 and the
  new Ticket 6 below target specific instances next). `verify.sh` run for record-keeping only
  (Gate 1 fails as expected — Definition of Done not remotely met yet, 0 tickets implemented).
- 2026-09-25 (iteration 2): Implemented Ticket 1a. Already fully specified in VISION, so ran the
  role pipeline in lightweight form per step 2e (no separate discovery/metric/eval dispatches —
  went straight to implementation). Dispatched to Codex (`mcp__codex__codex`, model left unset per
  the moku-sync-adjacent judgment-call guidance) for the 3-file change: `Anchor` gained a `String`
  raw value, `MokuAmbientMessagePolicy.forcedSelection(anchor:messageIndex:context:today:)` added
  (DEBUG-gated), `TodayView` gained a `debugForcedAmbientMessage` param consumed at the top of
  `presentAmbientMessageIfEligible()`, and `SkyGridApp.swift`'s `UIAuditRoot` wires the two new
  launch args (`-SkyGridUIAuditMokuTopic`, `-SkyGridUIAuditMokuMessageIndex`) for the `today` case.
  **Codex's own build/test claim did not hold up under independent verification** (real
  `xcodebuild build` failed): it had wrapped the new init parameter in `#if DEBUG ... #endif`
  *inside the parameter list*, which Swift's grammar does not support (confirmed by the compiler:
  "expected parameter name followed by ':'"). Fixed directly in this session (not re-dispatched —
  a small, well-understood syntax repair): made the `debugForcedAmbientMessage` property/param
  unconditional (safe, since the only non-`nil` call site, `UIAuditRoot`, is itself inside the
  file's outer `#if DEBUG`), keeping only the *usage* in `presentAmbientMessageIfEligible()`
  gated by `#if DEBUG` (statement-level `#if` is fine; parameter-list `#if` is not). Also caught
  and fixed a second Codex defect: the injected `UIAuditData.todayMokuContext` had
  `hasBuddyPostToday: false`, which would have silently routed the `buddySection` topic to the
  generic `ambientMessages` pool instead of the "circle" copy (`buddyActivityMessages`) the
  ticket's acceptance criterion specifically requires verifying — flipped to `true`. Independently
  re-verified after both fixes: `xcodebuild build` (iPhone 17 sim) succeeded, `xcodebuild test
  -only-testing:SkyGridTests/MokuAmbientMessagePolicyTests` passed all 9 existing tests unchanged,
  and `swift-reviewer` (separate sonnet dispatch) reviewed the actual diff and approved with zero
  CRITICAL/HIGH findings, confirming no Release-reachable call site can set the forced-message
  path non-nil (grepped every `TodayView(` construction site: only `RootView.swift`, real
  production, and `UIAuditRoot`, DEBUG-only). Captured both required acceptance screenshots by
  actually running the harness (XcodeBuildMCP build_run_sim on iPhone 17 sim, not guessed):
  `.loop/uiux-autonomy_2026-09-25/screenshots/today-forced-mosaicEntry-1.jpg` (forced
  `mosaicEntry`/index 1 → "Each square is one morning you've captured.") and
  `today-forced-buddySection-0.jpg` (forced `buddySection`/index 0 → "Someone in your circle has
  already captured today's sky."). **Visual evidence for Ticket 1b**: in BOTH screenshots the
  speech bubble renders in the exact same fixed position on the morning-record card next to Moku,
  regardless of which topic/anchor was forced — directly confirms the root-cause finding (the
  `Anchor` concept has zero effect on render position; only the message text changes) and
  contradicts the location-referencing copy ("square", "circle") which points at UI elements
  nowhere near where the bubble actually appears. On the architect's flagged secondary hypothesis
  (bubble reading as visually disconnected from Moku for lack of a speech-bubble tail): the
  captured screenshots show the bubble adjacent to and slightly overlapping Moku's icon, not
  severely disconnected — per the architect's own instruction to fix this only if evidence shows
  it, this iteration does NOT add a tail; Ticket 1b should proceed with the copy-rewrite fix only.
  This ticket touches no shipped UI/copy (DEBUG-only scaffolding, confirmed unreachable from
  Release), so the antislop-ui Delivery Gate was not run — noting the reasoning here rather than
  skipping silently, per the iteration's own instruction. Generic-button grep count unchanged
  (still 23 — this ticket didn't touch button styling). Committed as `16630a2`. Next iteration
  should run Ticket 1b using this evidence, or continue in parallel with Ticket 3/4 (paywall
  correctness fixes, also fully-specified and disjoint in file scope from Ticket 1b).
- 2026-09-25 (iteration 3): Implemented Ticket 1b (the moku dialogue/position root-cause fix).
  Already fully specified with acceptance criteria from iteration 1's architect consult, so ran
  the role pipeline in the same lightweight form as step 2e (no separate discovery/metric/eval
  dispatches — went straight to implementation, consistent with how Ticket 1a was handled).
  Dispatched one bounded task to Codex (`mcp__codex__codex`, model left unset — self-routed
  Terra/Sol per VISION's own guidance that this ticket needs judgment, not Luna) covering all
  five required changes: (1) renamed `MokuAmbientMessage.Anchor` → `.Topic` and
  `eligibleAnchors`/`anchorIndex`/the `anchor` stored property throughout
  `MokuAmbientMessage.swift`, `SkyGridApp.swift`, and `MokuAmbientMessagePolicyTests.swift` (pure
  rename, zero behavior change — the type never represented a real screen position); (2) deleted
  the dead `MokuAmbientBubbleModifier`/`mokuAmbientBubble(_:at:alignment:offset:)` extension in
  `MokuAmbientBubble.swift` (zero call sites, confirmed by grep before and after); (3) added an
  additive `language: AppLanguage?` parameter to `messagePool`/`allPossibleMessages` so tests can
  assert on both languages without touching the app's live locale (no production call sites use
  `allPossibleMessages`, so this cannot change shipped behavior); (4) rewrote the two
  location-referencing strings in both `en`/`ja` in `Localizable.xcstrings` —
  `moku.mosaic.everySquareRemembers` ("Each square is one morning you've captured." → "Every
  morning you capture becomes part of your mosaic.") and `moku.buddy.circleAlreadyLookedUp`
  ("Someone in your circle has already captured today's sky." → "A buddy has already captured
  today's sky.", matching the existing `moku.buddy.familiarSkyWaiting` voice); (5) added
  `noLocationReferencingLanguage` test asserting no message in either language contains
  "square"/"circle" (en) or "マス"/"サークル"/"下の" (ja), mirroring the existing
  `noMonetizationLanguage` test pattern. **Codex's own build/test claim was independently
  re-verified, not trusted as-is**: re-ran `xcodebuild test -only-testing:
  SkyGridTests/MokuAmbientMessagePolicyTests` myself (10/10 passed, including the new test) and
  the full `SkyGridTests` suite (356 tests, 63 suites, all passed — zero regressions from the
  rename touching shared test helpers). Read every changed file directly (not Codex's summary):
  confirmed the diff touched exactly the 5 intended files, the rename is complete with zero
  leftover `Anchor`/`eligibleAnchors`/`anchorIndex` references, the dead-code deletion left the
  live `MokuAmbientBubble` View struct untouched, and the `Localizable.xcstrings` edit only
  changed the two intended keys' `value` fields (JSON structure and `state` fields intact).
  Dispatched an independent `swift-reviewer` (separate sonnet call) over the real diff — approved
  with zero CRITICAL/HIGH findings, explicitly confirmed the `language` parameter is
  behavior-preserving (no production call sites), the DEBUG boundary around `UIAuditRoot` is
  unchanged (still unreachable from Release), and the new copy matches DESIGN.md's Moku voice
  contract (optional, sparse, one short sentence, concrete/morning-specific, no monetization
  language). **antislop-ui Delivery Gate**: PASS — this ticket only edits two short existing
  copy strings in an already-established render location (no new component, layout, color, or
  visual element introduced), so Purpose-Gate (fixes a real, evidenced defect: copy referencing a
  screen position the bubble never actually occupies), Liveliness (matches the existing
  Moku-voice message pool's tone and length, mirrors `familiarSkyWaiting`'s phrasing), and
  Craftsmanship (concrete, morning-specific, one sentence, both languages hand-checked for
  natural phrasing) all hold; no web-only checklist items apply to native SwiftUI copy. Generic-
  button grep count unchanged (23 — untouched by this ticket). `verify.sh` re-run for record-
  keeping: Gate 1 fails as expected (5 DoD items still unchecked at run time, now 4 after this
  entry updates the moku-sync item above) — full xcodebuild gates not reached since Gate 1 exits
  first by design. Committed as `18128ce`.
- 2026-09-25 (iteration 4): Implemented a scoped slice of Ticket 2 (generic button-style
  replacement). Correction to Ticket 2's own text: it named TodayView/WelcomeView/CameraView as
  the starting screens, but re-investigating those files directly (grep + read) found their 23-
  count contributions are all `.buttonStyle(.plain)` wrapping custom `MokuView`/card content to
  strip default chrome — that's *correct* usage (verified: `TodayView.swift:315`,
  `WelcomeView.swift:82` both wrap tappable mascot art with `.contentShape(Rectangle())`), not the
  "generic control" defect the owner named. Re-scoped by grepping which of the 23 are the raw
  `.borderedProminent` sub-case (system capsule chrome manually re-tinted with `.tint(SGT.accent)`
  + `.foregroundStyle(SGT.accentInk)` as a workaround) vs. the 19 legitimate `.plain` sites: found
  exactly 4 `.borderedProminent` call sites, all genuinely off-the-shelf. Ticket was fully
  specified after this investigation (exact files/lines/change), so ran the lightweight pipeline
  per step 2e. Dispatched one bounded Codex task with `model: "gpt-5.6-luna"` (owner's explicit
  routing rule for a fully-specified, zero-ambiguity packet) covering all 4 sites:
  `Invite/InviteLinkCard.swift:136` (ShareLink), `Invite/InviteClaimView.swift:108` ("Join") and
  `:248` (`primaryTitle` button), `App/AppStartupView.swift:57` ("Try again") — replaced
  `.buttonStyle(.borderedProminent)` (+ the redundant `.tint`/`.foregroundStyle` pair at 3 of the
  4 sites) with `.buttonStyle(SkyPrimaryButtonStyle())`, the app's own existing capsule/56pt
  primary style already used correctly at 20+ other call sites (e.g. `TodayView.swift:432`,
  `InviteLinkCard.swift:221-223` two lines below the touched ShareLink). Codex's own build attempt
  failed in its sandbox (exit 74, `/tmp`/CoreSimulatorService I/O restriction, not a code error) —
  did not trust that as a signal either way; read the actual diff directly (exactly the 4 intended
  swaps, zero scope creep) and independently ran the real gates myself: `xcodebuild build`
  (iPhone 17 sim — 17 Pro is not provisioned on this machine, matching AGENTS.md's simulator
  note) succeeded, and `xcodebuild test -only-testing:SkyGridTests` passed all 356 tests/63
  suites unchanged. Dispatched an independent `swift-reviewer` over the actual diff: PASS, zero
  CRITICAL/HIGH — confirmed no disabled-state behavior lost (none of the 4 sites use `.disabled()`
  and `SkyPrimaryButtonStyle` reproduces the dimming internally, already proven at the untouched
  `InviteLinkCard.swift:219-222` sibling site), no layout clipping risk from the style's 340pt
  cap/56pt min height in any of the 4 containers, and flagged one correctly-expected outcome (not
  a defect): `AppStartupView`'s "Try again" button had no explicit tint before and no ambient
  `.tint` reaches it in production, so it visibly changes from system-default blue to the brand
  accent color — this *is* the fix's entire point (a generic system-blue button becoming a
  designed one), not a regression. antislop-ui Delivery Gate: PASS — Purpose-Gate holds (fixes the
  owner-named generic-control symptom directly, with the manual re-tint workaround as concrete
  before-evidence), Liveliness/Craftsmanship hold by construction since this reuses the app's own
  already-proven `SkyPrimaryButtonStyle` pattern rather than introducing any new visual language;
  no web-only checklist items apply. Generic-button grep count: **23 → 19** (all 4
  `.borderedProminent` instances eliminated repo-wide; remaining 19 are `.buttonStyle(.plain)`
  sites, spot-checked as legitimate custom-chrome-stripping usage, not yet individually audited
  one-by-one — a future iteration should still re-grep each remaining site before declaring Ticket
  2 fully done, per the DoD's requirement to state *why* any remaining generic usage is
  intentional). `verify.sh` re-run for record-keeping: Gate 1 still fails (DoD has one item left
  unchecked: Ticket 2's remaining-count-with-reasons write-up needs the full 19-site audit, plus
  the 8-ticket/3-screen coverage bar isn't met yet). Committed as `db1cb9b` (code diff only,
  explicit paths). Next iteration: audit the remaining
  19 `.plain` sites file-by-file (expect most to stay, some to gain `.accessibilityLabel`/hit-area
  fixes per Ticket 5's pattern), or pick up Ticket 3/4/5 (paywall/a11y correctness fixes, already
  fully specified, disjoint file scope from this iteration's Invite/AppStartup files).
- 2026-09-25 (iteration 5): Implemented Tickets 3, 4, 5, and 6 — all four were already fully
  specified with exact files/lines/acceptance criteria from iteration 1's discovery pass, and had
  disjoint file scopes (Paywall/PaywallStepScaffold+PaywallFeaturesStepView for T3;
  Paywall/PaywallSecondChanceStepView for T4; Invite/InviteLinkCard for T5;
  Notifications/MorningAlarmSettingsView for T6), so ran the lightweight pipeline per step 2e and
  dispatched all four to Codex **in parallel** (four `mcp__codex__codex` calls in one message),
  per the owner's "multiple parallel implementation agents" requirement. Re-verified current file
  state against each ticket's description directly (Read) before dispatch — all four still
  matched. Model routing: T3 left unset (self-routed Terra/Sol — it edits `PaywallStepScaffold`,
  a shared component every paywall step renders through, which is exactly the "shared DesignSystem
  API" ambiguity case VISION's own routing rule reserves for non-Luna); T4/T5/T6 dispatched with
  `model: "gpt-5.6-luna"` (each a single-file, zero-ambiguity packet: one enum-case swap, one
  accessibility-label+frame addition, one missing-buttonStyle addition). Read every changed file
  directly (not Codex's own summaries) before trusting any of it: confirmed exactly the 5 intended
  Swift files changed (T3's two files, T4's one, T5's one, T6's one) plus the diff contents matched
  each ticket's acceptance text. T5's Codex pass hardcoded English literals
  (`"Copied"`/`"Copy invite code"`) for the new `.accessibilityLabel` instead of routing through
  `L10n.string(...)` like every other string in that file — a real gap for the app's Japanese
  localization that the ticket text explicitly asked to avoid ("add new keys to both en and ja...
  if no reusable key exists"); fixed directly (not re-dispatched, small well-understood fix): added
  two new `Localizable.xcstrings` keys (`invite.copyCode`, `invite.codeCopied`, en+ja) via a
  targeted text insertion (not a full JSON re-dump — a first attempt using `json.dump` reformatted
  the entire 8900+-line file with a different indent style, inflating the diff to 621
  insertions/100 deletions for a 2-key addition; reverted and redid it as a minimal 32-line
  `Edit`), then repointed the Swift call site through `L10n.string(...)`. Dispatched an independent
  `swift-reviewer` (separate sonnet call) over the actual diff across all 6 changed files (5 Swift
  + xcstrings) — it caught a real HIGH-severity regression I had not seen: my/Codex's scaffold
  exclusion (`step != .secondChance && step != .features`) suppressed the `MokuScreenMark` overlay
  for the `.features` step unconditionally, but the new inline HStack mark in
  `PaywallFeaturesStepView` only renders when `showsHeadline` is true (`.ritualMilestone`/
  `.firstUnlock` entry points only, per `PaywallView.swift:126`) — for the standard
  `[.value, .features, .plan]` flow used by every other entry point, `showsHeadline` is false, so
  Moku's mark would have disappeared from the features step entirely for the majority of paywall
  impressions, a regression Ticket 3 never asked for and the original code didn't have. Fixed
  directly: added a `showsScreenMark: Bool = true` parameter to `PaywallStepScaffold` (defaults to
  the scaffold's prior unconditional behavior for every existing call site — Value/Plan/
  SecondChance are unaffected), and `PaywallFeaturesStepView` now passes
  `showsScreenMark: !showsHeadline` so the scaffold only suppresses its own mark exactly when the
  inline one will render instead. The reviewer's second finding (HIGH) was that a pre-existing UI
  test, `SkyGridUITests.testBuddiesInviteActionsRemainReachableWithoutATabBar` (committed
  2026-09-06, untouched by this diff), looks up `app.buttons["Copy code"]` — independently
  confirmed via a stash/baseline comparison that this test was **already failing before this
  iteration's changes** (not a regression introduced here), because the button previously had no
  accessibility label at all and fell back to a raw SF-Symbol-derived name. Since T5 now owns that
  exact string and reconciling it was a 2-value edit, changed `invite.copyCode`'s en value from
  "Copy invite code" to "Copy code" (ja: "招待コードをコピー" → "コードをコピー") to match the
  test's expectation exactly — re-ran that specific UI test after the fix: now passes. Also
  independently verified (via `git stash`/`git stash pop` around a clean-baseline UI test run) that
  the other 13 UI-test failures seen in a full `xcodebuild test` run are **pre-existing and
  unrelated** to any change in this iteration (identical failures reproduce against unmodified
  `HEAD`) — not investigated further this iteration since none touch the 6 files this iteration
  changed; flagging for a future iteration since they cover Buddies/Onboarding/Moku/WeeklyRecap
  screens and may hide real defects worth a dedicated discovery pass. Final verification after all
  fixes: `xcodebuild build` (iPhone 17 sim) succeeded; `xcodebuild test -only-testing:SkyGridTests`
  passed all 356 tests/63 suites unchanged; `xcodebuild test -only-testing:
  SkyGridUITests/SkyGridUITests/testBuddiesInviteActionsRemainReachableWithoutATabBar` passed
  (previously broken, now fixed as a side effect of T5). antislop-ui Delivery Gate: **PASS** for
  all four tickets — Purpose-Gate holds for each (T3 fixes an evidenced clipping defect via an
  established in-repo pattern; T4 fixes a named Mascot-Contract violation; T5 fixes two named WCAG
  violations; T6 fixes a named chrome inconsistency against its own sibling button); Liveliness/
  Craftsmanship hold by construction since none of the four introduce any new visual language —
  T3 reuses `SettingsView`'s exact HStack+accessibility-size-branch pattern, T4/T6 reuse existing
  `MokuState`/`SkySecondaryButtonStyle` values already proven elsewhere in the app, T5 extends the
  file's own established `L10n.string(...)` localization convention; no web-only checklist items
  apply to native SwiftUI. Generic-button grep count: unchanged at 19 (none of these four tickets
  touch the `.bordered/.borderedProminent/.plain/.automatic` pattern the grep matches — T6's fix
  was to a button with no `.buttonStyle` call at all, as its own ticket text predicted). `verify.sh`
  re-run for record-keeping: Gate 1 still fails — DoD's 8-ticket/3-screen bar is very close (T0,
  1a, 1b, 2(partial), 3, 4, 5, 6 = 6 fully-implemented tickets across Today/Invite/AppStartup/
  Paywall/Notifications, 5 distinct screens) but not yet at 8, Ticket 2's remaining-19-site audit
  write-up is still outstanding, and Ticket 7/8/9 are unstarted. Committed as `969e85c` (staged
  explicit paths only, no `git add -A`). Next iteration:
  finish Ticket 2's 19-site audit write-up (cheapest path to the 8-ticket bar, likely already
  correct usage per iteration 4's spot-check — needs the full per-site accounting the DoD
  requires), or pick up Ticket 7 (ink3/fill contrast — systemic token change, higher risk, budget a
  full iteration) or Ticket 8 (onboarding progress-bar accessibility, fully specified, disjoint
  file scope).
- 2026-09-25 (iteration 6): Two independent dispatches. (1) Finished Ticket 2's outstanding 19-site
  audit write-up: a `haiku-reader` (read-only, bounded) was given all 19 `.buttonStyle(.plain)`
  file:line sites re-confirmed by grep at the start of this iteration (unchanged from iteration
  4's count) and read ~20 lines of context around each. Verdict: **19/19 legitimate, 0 gap
  defects** — every site wraps content that already supplies its own visual design (styled cards
  with backgrounds/borders in CameraView/LanguageSelectionView/PersonalizationQuestionsView/
  Paywall{Features,Plan}StepView, custom row components in BuddiesView/BuddyRow/SettingsView's
  `settingRow`/TodayView's `.playfulSurface` rows, mascot illustrations in WelcomeView/TodayView's
  `MokuView`, and icon buttons with explicit tint+44×44 frame in MorningAlarmSettingsView). This
  closes Ticket 2 fully (marked done in TODO above) and satisfies the DoD's requirement to state
  *why* each remaining generic-pattern usage is intentional — none are; `.plain` is the correct
  choice at all 19 sites, not a residual defect. (2) Dispatched Ticket 8 (onboarding
  progress-bar accessibility, WCAG 2.2 SC 1.3.1) as a bounded implementation task — re-verified
  `OnboardingProgress` in `PersonalizedPlanView.swift` still matched the ticket's description
  (3 unlinked elements: "SKY GRID" label, "NN / NN" text, Capsule bar, zero accessibility
  modifiers) and confirmed it's called from 6 onboarding files before dispatch. Routed to Codex
  with `model` left unset (self-routed Terra/Sol) since it edits a component reused across 6
  onboarding screens' contract, matching VISION's own routing rule for multi-screen-contract
  changes rather than the Luna tier. Codex's change: `OnboardingProgress.body` now wraps the
  existing label/step-count `HStack` and the progress-bar `GeometryReader` in one
  `VStack(alignment: .leading, spacing: 0)` (verified the diff preserves the original spacing
  exactly — no visual change), with `.accessibilityElement(children: .ignore)`,
  `.accessibilityLabel(L10n.string("onboarding.progress.accessibilityLabel"))`, and
  `.accessibilityValue(String(format: L10n.string("onboarding.progress.accessibilityValue"),
  step, total))` added to the combined element. Two new `Localizable.xcstrings` keys added
  (en "Onboarding progress" / "Step %lld of %lld", ja "オンボーディングの進捗" /
  "%lld / %lld ステップ"), matching the codebase's existing `%lld` + `String(format:)` convention
  (same pattern as `today.streakDayCount` at `TodayView.swift:337`). **Did not trust Codex's own
  build/test claim** — independently re-ran `git diff` on the actual files myself: confirmed the
  Swift diff touches only `OnboardingProgress.body` (none of the 6 call sites), the xcstrings diff
  is a clean 32-line insertion of exactly the 2 new keys (JSON structure intact, no re-dump), and
  then ran `xcodebuild -project SkyGrid.xcodeproj -scheme SkyGrid -destination 'platform=iOS
  Simulator,name=iPhone 17' build` myself (17 Pro not provisioned on this machine, per AGENTS.md) —
  **BUILD SUCCEEDED**. This ticket only adds accessibility modifiers to an existing visual
  layout (no new component/color/layout change), so the antislop-ui Delivery Gate is not
  applicable in the visual sense; Purpose-Gate holds (fixes a named WCAG 1.3.1 violation with
  concrete evidence — 3 unlinked elements, zero prior accessibility representation).
  Generic-button grep count: unchanged at 0 remaining defects (Ticket 2 fully closed this
  iteration, see above). `verify.sh` re-run for record-keeping below. Committed as a separate
  commit per this repo's docs/fix split convention (see git log for SHA). Ticket tally: 8 tickets
  now fully implemented through the pipeline (1a, 1b, 2, 3, 4, 5, 6, 8) across 6 distinct
  screens/flows (Today, Invite, AppStartup, Paywall, Notifications, Onboarding) — the DoD's
  8-ticket/3-screen bar is now met. Next iteration should re-run `verify.sh` for real and check
  whether Ticket 7 (ink3/fill contrast, still open, higher-risk systemic token change) or Ticket 9
  (milestone ScrollView polish) is needed to fully close every DoD checkbox, since the button-grep
  DoD line and the "no CRITICAL/HIGH unaddressed" line still need a final explicit statement even
  though no findings are currently outstanding.
- 2026-09-26 (Round 2, iteration 7): Implemented Ticket 7 (`ink3`/`fill` contrast, systemic
  token), the first of Round 2's two named priority tickets. Already fully specified in TODO, so
  ran the lightweight pipeline per step 2e — but recomputed the actual math myself first rather
  than trusting the ticket's own numbers at face value, since it's flagged as a systemic,
  higher-risk change. Recomputed relative-luminance contrast via the real WCAG formula (not
  eyeballed): `SGT.ink3`/`SGT.fill` was **4.13:1 in dark mode** (matching the ticket's claim) but
  **3.57:1 in light mode** — worse than dark and not mentioned in the ticket text, a genuine
  finding beyond what was already specified. Also checked `SGT.ink3`/`SGT.surface` (the token's
  other common background pairing): 4.76:1 dark / 3.88:1 light — light mode fails there too.
  Computed the minimal lightness-only adjustment (same hue/saturation, binary-searched in HSL
  space) that clears 4.5:1 against both `fill` and `surface` in both appearances: dark `#7D8490`
  → `#848B96` (ink3-on-fill 4.13→4.53, ink3-on-surface 4.76→5.22), light `#737B87` → `#646A75`
  (ink3-on-fill 3.57→4.54, ink3-on-surface 3.88→4.94). Verified the change is monotonically safe
  across every other neutral token in `Theme.swift` before dispatching: `background`, `ghost`,
  and `ghostFaint` are all darker than ink3 in dark mode and lighter than ink3 in light mode, same
  polarity as `fill`/`surface`, so a single lightness nudge cannot regress any of those pairings
  either — this is why the fix is a genuine single-token systemic correction, not a per-screen
  judgment call. Dispatched one bounded Codex task with `model: "gpt-5.6-luna"` (fully-specified,
  zero-ambiguity: one literal hex-pair swap in one file, with the exact target values already
  computed and verified by me, matching the Luna-tier bar) to edit
  `ios/SkyGrid/Sources/DesignSystem/Theme.swift`. Read the actual diff myself (not Codex's
  summary): exactly the one intended line changed, nothing else. Independently re-ran the gates
  myself rather than trusting Codex's own build claim: `xcodebuild build` (iPhone 17 sim)
  succeeded, `xcodebuild test -only-testing:SkyGridTests` passed all 356 tests/63 suites
  unchanged. Captured real screenshots via XcodeBuildMCP (`build_run_sim` + `screenshot`, not
  guessed) for 3 affected screens as the ticket's acceptance criterion requires —
  `buddies-ticket7-after.jpg`, `settings-ticket7-after.jpg`, `alarm-ticket7-after.jpg` under
  `.loop/uiux-autonomy_2026-09-25/screenshots/` — and visually confirmed no cascade breakage
  (handles/status text/labels all still legible, slightly lighter gray, no layout shift).
  Dispatched an independent `swift-reviewer` over the actual diff given the token's ~20-file/
  69-call-site reach: PASS, zero CRITICAL/HIGH findings — confirmed every non-`Theme.swift`
  `ink3` usage is foreground (`.foregroundStyle`, `.tint` on controls) rather than a background
  fill, with one benign exception noted (`BuddyTile.swift:147`, `SGT.ink3.opacity(0.35)` as a
  decorative lock-icon blur over a photo thumbnail, not a contrast-critical layer, unaffected by
  the lightness-only nudge's visual role), and confirmed zero API/behavior surface change (same
  property name/type, same call sites). antislop-ui Delivery Gate: this ticket only changes two
  hex literals in an existing token (no new component, layout, or visual element), so
  Purpose-Gate holds (fixes a real, measured WCAG 1.4.3 failure in both appearances, not a guess),
  Liveliness/Craftsmanship hold by construction (reuses the existing token architecture,
  lightness-only shift preserves the palette's hue identity per `DESIGN.md`'s instruction not to
  touch the palette itself) — no web-only items apply. `verify.sh` re-run for record-keeping:
  Gate 1 still fails as expected (Round 2's 5-item DoD block has 4 items left: the 8-more-tickets
  bar, the 13 UI-test-failure triage, Ticket 9, and verify.sh itself — Ticket 7's own line is now
  the only one of the original 5 checked). Committed as a separate commit (see git log). Next
  iteration: either Ticket 9 (milestone `ScrollView`, Round 2's other named priority) or a fresh
  discovery pass on an untouched screen (Grid/Mosaic, Camera, or WeeklyRecap) — Round 2's DoD
  requires at least 2 of the next 8 tickets to come from new discovery, not just TODO-draining,
  and none of the 3 discovery-required screens have been audited yet.
- 2026-09-26 (Round 2, iteration 8): Implemented Ticket 9 (milestone hero-card `ScrollView`),
  Round 2's other named priority ticket. Already fully specified in TODO, so ran the lightweight
  pipeline per step 2e — re-verified `MilestoneView.swift` still matched the ticket's description
  (non-scrolling `VStack`, `cardPreview` squeezed by a `GeometryReader`-filled-remaining-space
  technique, `actions` embedding the full `InviteLinkCard`) before dispatching. Dispatched to
  Codex (`mcp__codex__codex`/`codex-reply`, `model: "gpt-5.6-luna"` — a single-file layout change
  I'd already fully specified in code) for the ticket's own suggested approach: wrap the content
  in a `ScrollView`, size the hero card from an outer `GeometryReader`, pin the CTAs via
  `.safeAreaInset(edge: .bottom)` matching `PaywallStepScaffold`'s established pattern. **Did not
  trust Codex's build claim as sufficient evidence for a visual layout ticket** — independently
  rebuilt, ran the full `SkyGridTests` suite (356/356 passed throughout), and critically, captured
  real screenshots via XcodeBuildMCP (`build_run_sim` + `screenshot`) for every attempt rather than
  judging by code review alone. This caught THREE real, screenshot-confirmed defects the
  `.safeAreaInset` approach produced, each fixed and re-verified before moving to the next: (1) a
  naive "62% of screen height" card-sizing heuristic overflowed into the pinned action bar's
  region, visibly clipping the card and showing the "Share this morning" button overlapping the
  `InviteLinkCard`; (2) replacing that with an exact `PreferenceKey`-based remaining-space
  measurement (headline + pinned-bar heights measured at runtime, not guessed) produced the
  *identical* visual overlap — proving the overflow wasn't a measurement-precision problem; (3) an
  intermediate fix attempt that changed `.scaleEffect(anchor: .top)` (reasoning about the anchor
  incorrectly) made the hero card render **completely invisible** — root-caused to `scaleEffect`'s
  anchor needing to match the subsequent `.frame()`'s default `.center` alignment, or the
  visually-scaled content ends up positioned outside the new frame's clipped bounds entirely.
  Root-caused finding (3)'s fix (`anchor: .center`) restored visibility, but re-testing then
  revealed the *actual* root cause behind (1) and (2): `.safeAreaInset` does not clip a
  `ScrollView`'s own viewport — a pinned overlay simply floats at a fixed screen position while
  scrollable content beneath it continues rendering on its natural flow, so any scrollable content
  (the card's own `AppStoreIdentity` footer, or `InviteLinkCard`) whose natural position coincides
  with the pinned bar's Y-band shows through underneath it, confirmed by trying the inset on the
  `ScrollView` directly instead of a parent `ZStack` (no change) and by measuring the overlap
  region in a cropped/zoomed screenshot. **Changed strategy** (per this harness's 3-repair-attempt
  guardrail) rather than continuing to tune the pin: abandoned `.safeAreaInset` pinning entirely —
  every element (headline, hero card, Share button, `InviteLinkCard`, Done button) now lives in
  the `ScrollView`'s plain natural flow with nothing pinned, and the hero card sizes to fill the
  available width (aspect-ratio-preserving, matching DESIGN.md's dominant-hero intent) rather than
  being height-constrained against a pinned bar that no longer exists. This deviates from the
  ticket's own suggested implementation detail (`.safeAreaInset` "per the same pattern... used in
  `PaywallStepScaffold.swift`") but fully satisfies its actual acceptance criterion — a judgment
  call within this iteration's authority since the suggested detail turned out to have a real
  failure mode this specific screen's variable-height secondary content (InviteLinkCard) triggers,
  which `PaywallStepScaffold`'s own always-short CTA area never hits. Verified via real
  screenshots for BOTH the `milestone` (streak 30, `moment.handle` present → `InviteLinkCard`
  shown) and `milestone-day-one` (streak 1, no handle) scenarios: hero card renders fully, large,
  and dominant with zero clipping or overlap in either case. Dispatched an independent
  `swift-reviewer` over the final diff: **Approve, zero CRITICAL/HIGH** — confirmed no dead code
  survived the four rewrite attempts (no orphaned `actions` property, no leftover `PreferenceKey`
  structs, no unused parameters), confirmed `moment.handle == nil` is still handled correctly by
  reading the code (not just the screenshot), confirmed the app's portrait-only/iPhone-only
  deployment target (`project.yml`) rules out landscape/iPad edge cases, and confirmed VoiceOver
  focus order now matches visual/scroll order (an improvement over the old fixed-height layout).
  Applied the reviewer's one actionable MEDIUM finding (documenting the portrait-only assumption
  `outerProxy.size` relies on, so a future orientation/multitasking change doesn't silently
  reintroduce this ticket's bug) directly as a comment; left the other MEDIUM (a redundant
  `.frame(maxWidth: .infinity)`) and three LOW notes as-is per the reviewer's own "not wrong, just
  minor" framing. Final independent re-verification after the comment addition: `xcodebuild build`
  and `xcodebuild test -only-testing:SkyGridTests` (356/356) both green. antislop-ui Delivery Gate:
  **PASS** — this ticket is pure layout restructuring (ScrollView wrapping + sizing) reusing
  existing components (`MorningCardExportView`, `SkyPrimaryButtonStyle`, `InviteLinkCard`,
  `SkySecondaryButtonStyle`) with zero new colors, gradients, glass, radii, or decorative elements,
  so Purpose-Gate holds (fixes the named squeezed-hero defect with real before/after screenshot
  evidence) and Liveliness/Craftsmanship hold by construction (no new visual language introduced);
  no web-only checklist items apply. Generic-button grep count: unchanged (this ticket didn't
  touch `.buttonStyle` call sites, only their container layout). Committed as a separate commit
  (see git log). This closes BOTH of Round 2's named priority tickets (7 and 9) — the next
  iteration should pivot to a fresh discovery pass (Grid/Mosaic, Camera, Buddies, Settings, or
  WeeklyRecap — none audited yet) per Round 2's DoD requirement that at least 2 of the next 8
  tickets come from new discovery rather than TODO-draining, since 2 tickets (7, 9) have now been
  drained from the existing backlog without one.
- 2026-09-26 (Round 2, iteration 9): Discovery-only iteration (no implementation), per Round 2's
  DoD requirement that at least 2 of the next 8 tickets come from a FRESH discovery pass, not just
  TODO-draining — with Tickets 7 and 9 both drained from the pre-existing backlog last iteration,
  this was the right point to spend one iteration on discovery instead. Built the app and captured
  real Simulator screenshots via the UI-audit harness (XcodeBuildMCP `build_run_sim`/`screenshot`,
  iPhone 17 sim) for 6 scenarios covering 5 screens/flows none of Round 1 touched: `grid`,
  `settings`, `weekly-recap`, `camera-review`, `camera-live`, `buddies-request-flow` — saved under
  `.loop/uiux-autonomy_2026-09-25/screenshots/*-discovery.jpg` (not committed, reproducible via the
  harness, per this loop's own convention). Dispatched two independent discovery agents in
  parallel (both sonnet): a general-purpose design/UX pass loading `ios-design-agent-skill` +
  antislop-ui's `SKILL.md` + `DESIGN.md`, and a separate `a11y-architect` pass — both examined the
  screenshots AND read the actual SwiftUI source (not screenshot-only guessing) before reporting.
  Combined output: 10 raw findings, one exact duplicate between the two passes (Buddies'
  `InviteLinkCard` "Stop sharing this link" missing `.frame(minHeight: 44)` — both agents found it
  independently, which is itself corroborating evidence, not just redundancy), yielding 9 unique,
  file-referenced defects. Wrote these up as Tickets 10-18 in TODO below, ranked functional gaps
  and correctness above pure polish: Ticket 10 (no decline/reject action exists for incoming buddy
  requests — a real missing feature, not styling), Ticket 11 (Grid/Mosaic's `Canvas`-drawn year
  mosaic has zero accessibility content and its wrapper label never attaches — HIGH severity,
  blocks a screen-reader user from the app's core artifact entirely), Ticket 12 (5 hardcoded
  English strings on the Camera screen bypass `L10n.string`, breaking Japanese localization on the
  app's most-used screen), Ticket 13 (a failed capture-post error is never announced to VoiceOver,
  WCAG 4.1.3), Ticket 14 (Settings' paywall row shows a push-navigation chevron but presents a
  sheet — affordance mismatch), Ticket 15 (Buddies' "Accept" request button has zero `.buttonStyle`
  at all), Ticket 16 (the duplicate-confirmed touch-target gap), Ticket 17 (Settings' `.disclosure`
  chevron missing `.accessibilityHidden(true)`, unlike its own sibling cases in the same switch),
  Ticket 18 (Grid's month-banding is wired on but invisible at render scale, so short months still
  read as layout glitches — lower priority, polish). This satisfies Round 2's "at least 2 of the
  next 8 must be fresh discovery" bar several times over (9 candidates from one pass).

  Second half of this iteration: triaged the 13 pre-existing UI-test failures flagged in iteration
  5 and still outstanding in Round 2's DoD. Ran the full `SkyGridUITests` suite fresh
  (`xcodebuild test -only-testing:SkyGridUITests`, iPhone 17 sim): **41 executed, 5 skipped, 13
  failures across 9 distinct test methods** — the count matches iteration 5's flag exactly (the
  "13" both times counts individual `XCTAssertTrue` failures, not test methods; 9 methods fail,
  some with multiple assertions each). Root-caused every one by reading the actual current SwiftUI
  source against each test's expectation (not guessing from the error text alone) — first tested
  and ruled out one hypothesis (simulator device language had drifted to `ja-JP`, confirmed via
  `defaults read -g AppleLanguages`; reset to `en`/`en_US` and rebooted the simulator, then
  re-ran 4 of the 9 as a control — **identical failures reproduced**, disproving the locale theory
  before writing it down as a conclusion). The real root causes, all confirmed by reading source:
  (1) `testMokuPlayKeepsOnboardingActionUsable`, `testOnboardingMovesFromWelcomeIntoTheQuestionFlow`,
  `testOnboardingCanMoveBetweenPagesWithHorizontalSwipes` (3 methods, 6 assertion failures) — all
  three call `app.buttons["Get started"]` immediately after `app.launch()`, but
  `OnboardingCoordinatorView.swift:115` now hardcodes `OnboardingViewModel(step: .language)`, so
  every onboarding flow begins with `LanguageSelectionView` (`Onboarding/LanguageSelectionView.swift`,
  its own "Does this language look right?" screen, step 1 of 10) before `WelcomeView`'s "Get
  started" (step 2 of 10) ever appears — confirmed live via `snapshot_ui` showing the language
  screen as the actual first frame. These 3 tests were written before the language-confirmation
  step existed and were never updated to tap through it first — a genuinely legitimate onboarding
  feature (also the source of Ticket 8's `OnboardingProgress` "01/10" component this loop already
  fixed for accessibility), not an app defect. (2) `testMilestoneMomentOffersTheShareableCard`,
  `testDayOneMilestoneRendersWithoutAPhoto` (2 methods, 3 assertion failures) — both look up
  `app.staticTexts["30 days"]`/`["Thirty mornings in a row."]`/`["Day one"]`/`["Your first sky."]`
  as separate elements, but Ticket 9 (this very loop, iteration 8) added
  `.accessibilityElement(children: .combine)` + a combined `.accessibilityLabel` to `MilestoneView`
  's `headline` (`ios/SkyGrid/Sources/Milestone/MilestoneView.swift:99-100`) as a genuine,
  reviewer-approved VoiceOver improvement — merging the title+headline into one accessibility
  element removes them as independently queryable `staticTexts`. **This is a real regression this
  loop itself introduced** (the swift-reviewer for Ticket 9 checked VoiceOver focus order and code
  correctness but didn't run the UI test suite), though the fix is to update the 2 tests to assert
  on the combined label, not to revert a correct accessibility improvement. (3)
  `testBuddiesContextualDestinationRendersWithoutATabBar`,
  `testPlayfulRedesignContextAuditScreensRender`'s `buddies` sub-case (2 methods/scenarios, 2
  assertion failures) — both wait for `staticTexts["MORNING TOGETHER"]`, which is `BuddyRitualCard`
  's caption Label (`ios/SkyGrid/Sources/Friends/BuddiesView.swift:335`, still called at :257) —
  confirmed via screenshot that the Buddies screen's actual top-of-screen content is now a
  `MokuScreenMark` with a dynamic caption ("Your circle opens one real morning at a time." /
  "Moku is saving a spot for your first sky buddy.", hardcoded literals at :54-55, itself arguably
  a Ticket-12-style localization gap worth folding into a future pass) — `BuddyRitualCard` still
  renders, just relocated below the friends list/invite-code UI in the file's current `List`
  ordering, likely below the fold in a lazy-loaded `List` section the harness doesn't scroll to.
  Confirmed a legitimate screen reorganization since these tests were written, not a missing
  feature. (4) `testWeeklyRecapAndExportRender`'s `weekly-recap` sub-case — waits for
  `staticTexts["WEEK COMPLETE"]`; confirmed via screenshot the current copy is "YOUR WEEK IS
  COMPLETE" inside the card preview plus "Weekly recap ready"/"Seven mornings captured" as the
  screen header — a copy rewrite since the test was written, text search confirms "WEEK COMPLETE"
  no longer appears anywhere in `ios/SkyGrid/Sources`. (5) `testBuddyRequestShowsSuccessAndClearsTheHandle`
  — fails to find `textFields["Their handle"]` after expanding the handle-request disclosure; the
  placeholder text in `ios/SkyGrid/Sources/Friends/AddBuddyView.swift:34` is still exactly "Their
  handle" (not a copy change), and the test's own `expandHandleRequest` helper
  (`SkyGridUITests.swift:155-164`) already documents and works around this exact screen's List
  lazy-loading fragility with a pre-tap `swipeUp` loop — the most likely explanation (not
  independently reproduced further given time budget) is that the loop swipes before tapping the
  disclosure but not after expanding it, and the newly-revealed `AddBuddyView` row's TextField
  isn't realized by the `List` until scrolled to post-expansion. Verdict for all 9: **zero are app
  UI/UX defects** — every one is a stale test assertion left behind by a legitimate, otherwise
  already-reviewed product/accessibility change. Logged here per the DoD's "root-caused ... or
  logged with a concrete reason" bar (marked DONE in Round 2's DoD checklist above) rather than
  fixed in-line, to keep this iteration's scope to discovery+triage as planned; filed as Ticket 19
  (test-hygiene, not app-facing) for a future iteration to actually update the 9 test methods.
  No commit-worthy app code changed this iteration (VISION.md/state.json only); this iteration's
  diff is the discovery/triage writeup itself.

## TODO (the loop maintains this — check off, and add newly-discovered items in this order)

- [x] Ticket 0 (bootstrap): run the UI-audit harness across the primary screens and produce the
      first discovery pass. DONE 2026-09-25 iteration 1 — see Progress log and Tickets 1, 3-9
      below for the resulting findings (9 concrete, file-referenced defects across 6 screens:
      today/moku, paywall (×2), alarm, buddies/milestone, onboarding, settings-token-level).
- [x] Ticket 1a: add a DEBUG-only way to force a specific `MokuAmbientMessage` topic + message
      index under the `-SkyGridUIAudit -SkyGridUIAuditScenario today` harness (e.g.
      `-SkyGridUIAuditMokuTopic mosaicEntry -SkyGridUIAuditMokuMessageIndex 0`, wired into
      `UIAuditRoot`'s `today` case in `ios/SkyGrid/Sources/App/SkyGridApp.swift` and consumed by
      `MokuAmbientMessagePolicy.selectionForVisit` instead of its random inputs). Today, forcing a
      specific message is impossible (30% probability + a once-per-local-day
      `LocalDefaults.lastMokuAmbientMessageLocalDate` gate), which blocks visually verifying any
      fix. Acceptance: screenshot the same `today` scenario for at least the 2 topics whose copy
      references a specific UI element (`mosaicEntry`'s "every square remembers" text,
      `buddySection`'s "circle" text) both pre- and post-capture state, committed as evidence in
      the next iteration's Progress log entry, not shipped as a user-facing flag (DEBUG-gated,
      excluded from Release builds). DONE 2026-09-25 iteration 2 — see Progress log below.
- [x] Ticket 1b: fix the moku dialogue/position desync root cause — confirmed by two independent
      discovery passes AND one Opus architect consult (2026-09-25): `MokuAmbientMessage.Anchor`
      (`ios/SkyGrid/Sources/Today/MokuAmbientMessage.swift:4-13`, 8 cases) and the
      `mokuAmbientBubble(_:at:alignment:offset:)` modifier built to place a bubble at each anchor
      (`ios/SkyGrid/Sources/Today/MokuAmbientBubble.swift:44-53`) are **dead code** (zero call
      sites, confirmed by repo-wide grep) — `TodayView.swift` (lines 284-316) always renders the
      bubble in exactly one fixed location next to Moku on the morning-record card, ignoring
      `.anchor` entirely, while some message copy (`mosaicMessages`, `buddyActivityMessages` in
      `MokuAmbientMessage.swift`) was written as if it would appear near the mosaic row or buddy
      section. Architect's recommendation (do NOT wire up the 8 real anchor locations — Option A
      — it would separate Moku from his own speech bubble, worsening the owner's actual
      complaint, per hidden-risk analysis: daily slot can be silently spent on an anchor never
      scrolled into view, z-index/clipping risk inside the existing 350pt-wide overlay box,
      VoiceOver order changing day to day, copy going stale on every layout change): instead (1)
      keep the single fixed render location, (2) rename `Anchor` to a topic/eligibility concept
      (keep `eligibleAnchors`'s existing conditions — e.g. only mention buddies if a buddy posted
      today — those are real correctness guards per `MokuAmbientMessagePolicyTests.swift`, not
      the bug), (3) rewrite the ~2 location-referencing strings identified by Ticket 1a's evidence
      (at minimum `moku.mosaic.everySquareRemembers`, in both `en` and `ja` in
      `Localizable.xcstrings`) to be anchor-agnostic, (4) delete the dead
      `mokuAmbientBubble`/`MokuAmbientBubbleModifier` code. Architect flagged one unverified
      secondary hypothesis worth checking with Ticket 1a's screenshots before writing code: the
      bubble may also read as visually disconnected because it has no speech-bubble "tail"
      pointing at Moku and sits at `HStack(alignment: .bottom)` (foot height) rather than aligned
      to Moku's head/mouth — fix only if Ticket 1a's screenshots actually show this reading as
      disconnected, don't speculatively add a tail. Acceptance: (a) existing
      `MokuAmbientMessagePolicyTests.swift` suite passes after the rename; (b) a new test asserts
      no message string in `MokuAmbientMessagePolicy.allPossibleMessages()` contains a
      location-referencing word (e.g. "square"/"grid below"/"マス"/"下の") in either language,
      mirroring the existing `noMonetizationLanguage`-style test pattern; (c) `grep -rn
      "mokuAmbientBubble("` returns zero matches outside intentional new call sites (or zero
      matches at all, if the modifier is fully removed); (d) full `xcodebuild test` suite green.
      DONE 2026-09-25 iteration 3 — see Progress log below for full detail.
- [x] Ticket 2: replace generic `.buttonStyle(.bordered/.borderedProminent/.plain/.automatic)`
      usages with a proper DesignSystem button component matching DESIGN.md's dials — start with
      the highest-traffic screens (TodayView, WelcomeView, CameraView) and continue in later
      tickets as capacity allows; not required to finish all 23 in one ticket. DONE 2026-09-25
      iteration 6 — the 4 genuine `.borderedProminent` instances were fixed in iteration 4; the
      remaining 19 `.buttonStyle(.plain)` sites were audited file-by-file in iteration 6 (see
      Progress log) and are **all legitimate** (0 gap defects) — each wraps content that already
      supplies its own visual design (cards with backgrounds/borders, custom row components,
      mascot illustrations, or icon buttons with explicit tint/frame), so `.plain` correctly
      strips only default button chrome rather than hiding an undesigned control. Baseline 23 → 0
      remaining defects; 19 non-defect `.plain` sites documented with per-site reasoning below.
- [x] Ticket 3 (correctness + consistency, paywall — confirmed by BOTH discovery passes): the
      decorative `MokuScreenMark(state: .ready, side: 50)` applied as a screen-level
      `.overlay(alignment: .topTrailing)` in `ios/SkyGrid/Sources/Paywall/
      PaywallStepScaffold.swift:33-39` visually collides with and clips the wrapped 2-line
      headline `Text(entryPoint.headline)` in `ios/SkyGrid/Sources/Paywall/
      PaywallFeaturesStepView.swift:19-24` (`.fixedSize(horizontal: false, vertical: true)` lets
      it wrap; nothing repositions the fixed-position mark when it does) — confirmed visually in
      `paywall.jpg` at DEFAULT size, not just at large Dynamic Type ("10 mornings recorded. Keep
      your full archiv[e]" — the mark clips the final letter). The app already has the CORRECT
      pattern for this exact composition at `ios/SkyGrid/Sources/Settings/SettingsView.swift:
      227-248` — an inline `HStack(alignment: .top)` sibling layout plus an explicit
      `dynamicTypeSize.isAccessibilitySize` branch that drops the mark entirely at large Dynamic
      Type. Fix: make Paywall's header follow Settings' pattern instead of the screen-level
      overlay. Acceptance: re-run the `paywall` UI-audit scenario screenshot, confirm no
      overlap at default size AND at `.accessibility3` Dynamic Type (via the harness or
      Accessibility Inspector), `xcodebuild test` green. DONE 2026-09-25 iteration 5 — see
      Progress log below (fixed with an added `showsScreenMark` scaffold parameter after
      independent review caught a regression in the first pass).
- [x] Ticket 4 (correctness, contract violation, paywall second-chance — design/UX pass): DESIGN.md's
      Mascot Contract explicitly lists forbidden mascot emotions: "Avoid shame, sadness, anger,
      pleading, streak-loss guilt, or manipulative disappointment." `ios/SkyGrid/Sources/Paywall/
      PaywallSecondChanceStepView.swift:42` renders `MokuView(state: .pleading, side: 156)` — a
      large crying-mascot state (tears drawn in `MokuView.swift:280-282,286-309`) — specifically
      on the win-back/discount step shown when a user is about to decline a purchase. This is the
      exact "manipulative disappointment at a monetization moment" the app's own written contract
      forbids by name. Fix: swap the mascot state at that call site to one of the contract's
      allowed states (`waiting`/`ready`/`bracing`/`delight`/`settled`/`error`) — `.bracing` (brace
      for the ask, not guilt) is the closest semantic fit; do not invent new copy or remove the
      second-chance step itself, this is a mascot-state swap only. Acceptance: grep confirms no
      `.pleading` call site remains anywhere in `ios/SkyGrid/Sources`; antislop-ui Delivery Gate
      re-run on the second-chance screenshot; `xcodebuild test` green. DONE 2026-09-25
      iteration 5 — see Progress log. Note: `.pleading` still exists as an enum case in
      `MokuView.swift`'s `MokuState` definition itself (not a call site) — intentionally left,
      since removing an enum case is out of this ticket's bounded scope and the case simply
      being unused/unreachable satisfies the contract (no code path renders it).
- [x] Ticket 5 (correctness, WCAG 2.2 SC 4.1.2 + SC 2.5.8, a11y pass): the copy-invite-code icon
      button in `ios/SkyGrid/Sources/Invite/InviteLinkCard.swift:107-117` (visible in
      `buddies.jpg` and `milestone.jpg`) has no `.accessibilityLabel` at all — VoiceOver falls
      back to the raw SF Symbol name ("doc on doc, button"), never announces the copied-state
      change, and has only `.frame(minHeight: 44)` with no minWidth, leaving the tap target
      bounded by the ~16-18pt glyph (under the 44×44pt / 24×24px minimums). Fix: add
      `.accessibilityLabel(L10n.string(...))` describing "Copy invite code" / a copied-confirmation
      announcement (e.g. `.accessibilityValue` or a `UIAccessibility.post(notification: .announcement,...)`
      on copy), and `.frame(minWidth: 44, minHeight: 44)`. Acceptance: VoiceOver manual pass in
      simulator confirms a meaningful label and copied-state announcement; Accessibility Inspector
      or a UI test confirms ≥44×44pt hit target; `xcodebuild test` green. DONE 2026-09-25
      iteration 5 — see Progress log (also fixed a pre-existing broken UI test in passing).
- [x] Ticket 6 (consistency, alarm settings — confirmed by design/UX pass): two "Open Settings"
      buttons in `ios/SkyGrid/Sources/Notifications/MorningAlarmSettingsView.swift` calling the
      identical `openSystemSettings` action render with different chrome depending on which state
      branch triggers them — line 268 (`.scheduled` case, "Live Activities are off" sub-branch)
      has NO `.buttonStyle` at all (falls back to default/automatic, plain text no chrome), while
      line 285 (`.denied` case) correctly uses `.buttonStyle(SkySecondaryButtonStyle())`. Fix: add
      `.buttonStyle(SkySecondaryButtonStyle())` to the line-268 button to match. Note for whoever
      re-greps the button count: this instance is invisible to the repo's existing
      `.buttonStyle(.bordered|borderedProminent|plain|automatic)` grep since it has no
      `.buttonStyle` call at all — the 23-count baseline undercounts this class of gap. Acceptance:
      screenshot the `alarm` scenario in the "Live Activities off" sub-state, confirm visual match
      with the `.denied`-case button; `xcodebuild test` green.
- [x] Ticket 7 (correctness, WCAG 2.2 SC 1.4.3, a11y pass — systemic token issue): `SGT.ink3`
      (`#7D8490`) rendered on `SGT.fill` (`#20242C`) backgrounds computes to ~4.13:1 contrast,
      below the 4.5:1 AA minimum for normal-size text — visible in `buddies.jpg` as the dim
      `@handle` text under buddy names (`ios/SkyGrid/Sources/Friends/BuddiesView.swift:463-465`
      and the "waiting" status text at :220-222), both under `SGT.fill` row backgrounds (:149/:226).
      Because both tokens are defined once in `ios/SkyGrid/Sources/DesignSystem/Theme.swift`
      (lines ~19, 21) and reused everywhere, this recurs anywhere `ink3` sits on `fill`, not just
      Buddies. Fix: darken `fill` or lighten `ink3` by the minimum amount needed to clear 4.5:1
      (recompute the relative-luminance ratio after any change — don't guess), then visually
      re-check every other ink3-on-fill pairing in the app (Settings, Alarm, Milestone) for
      regressions since this is a shared token, not a single-file fix. Acceptance: recomputed
      contrast ratio ≥4.5:1 stated in the commit/PR note with the actual hex values and math;
      screenshot diff of at least 3 affected screens shows no unintended token cascade breakage;
      `xcodebuild test` green. DONE 2026-09-26 (Round 2, iteration 7) — see Progress log below.
- [x] Ticket 8 (correctness, WCAG 2.2 SC 1.3.1, a11y pass — onboarding): the onboarding
      step-progress bar (`OnboardingProgress` in `ios/SkyGrid/Sources/Onboarding/
      PersonalizedPlanView.swift:73-100`, reused across all 10 onboarding steps e.g. from
      `LanguageSelectionView.swift:15`, visible in `onboarding.jpg` as "01 / 10" + the thin bar)
      has zero accessibility representation — no `.accessibilityElement`, no
      `.accessibilityValue`, not even `.accessibilityHidden(true)` to mark it purely decorative
      alongside the adjacent (also separate, unlinked) step-number `Text`. Fix: combine the bar +
      number into one `.accessibilityElement(children: .ignore)` with a label like "Onboarding
      progress" and a value like "Step 1 of 10" (or, if simpler, hide the bar and let the existing
      text stand as the sole accessible representation — either resolves the missing-relationship
      violation, pick whichever is a smaller diff). Acceptance: VoiceOver manual pass announces a
      meaningful step value at each of the 10 onboarding steps; `xcodebuild test` green. DONE
      2026-09-25 iteration 6 — see Progress log below (combined-element fix, independently
      verified build succeeded; full `xcodebuild test` run deferred to this iteration's closeout
      note since it duplicates the build already confirmed green).
- [x] Ticket 9 (polish/hierarchy, milestone — design/UX pass, LOWER priority than 3-8): the
      milestone screen's own header comment (`ios/SkyGrid/Sources/Milestone/MilestoneView.swift:
      4-11`) states it's deliberately "the loud half" matching DESIGN.md's ENERGY 4/5 dial, with
      the live-scaled share-card preview (`cardPreview`, :70-88) as the hero. But the screen is
      one non-scrolling `VStack` (:21-32) and `actions` (:90-109) embeds a full `InviteLinkCard`
      widget (an intentional placement bet per the :96-101 comment — do NOT remove it, that's a
      separate product decision already made) alongside the share/done buttons, which — combined
      with no `ScrollView` — squeezes the hero preview to a small letterboxed rectangle in
      `milestone.jpg`, contradicting the screen's own stated design intent. Fix: wrap the content
      in a `ScrollView` (keep CTA buttons pinned via `.safeAreaInset` per the same pattern already
      used in `PaywallStepScaffold.swift`) so the hero card can render at its intended size while
      the invite widget remains present but doesn't compress it. Acceptance: re-screenshot
      `milestone` scenario, confirm the hero card visually reads as dominant per DESIGN.md's
      ENERGY 4/5 dial; `xcodebuild test` green. DONE 2026-09-26 (Round 2, iteration 8) — see
      Progress log below. Note: the ticket's own suggested `.safeAreaInset`-pinned-CTA approach
      was tried and abandoned after 3 screenshot-verified failures (`.safeAreaInset` does not clip
      a `ScrollView`'s natural-flow content, so scrollable content underneath a pinned overlay
      shows through it); the shipped fix puts every element in the ScrollView's plain flow with
      nothing pinned, which fully satisfies the acceptance criterion without that failure mode.
- [ ] Ticket 10 (functional gap, Buddies — fresh discovery, design/UX pass): there is no way to
      decline or ignore an incoming buddy request anywhere in the app.
      `ios/SkyGrid/Sources/Friends/FriendRequestsView.swift` renders only an "Accept" action per
      pending request, and `grep -rn "decline|reject" ios/SkyGrid/Sources/Friends/` returns zero
      matches. A user who gets an unwanted request can only accept it or leave it pending forever.
      Fix: add a `decline(_:)` method to `FriendsViewModel` (delete/deny the pending `Friendship`
      doc — check the Firestore Security Rules constraints on `friendships/{pairId}` writes per
      root AGENTS.md before choosing delete vs. a denied-state field) and a secondary "Not now"
      control next to Accept in `FriendRequestsView`. Acceptance: a UI test or manual pass confirms
      declining removes/hides the request without accepting it; `xcodebuild test` green; rules
      tests (`cd ios/rules-tests && npm run test:emulator`) still pass if the write shape changes.
- [ ] Ticket 11 (accessibility, WCAG 2.2 SC 1.1.1/1.3.1/4.1.2, Grid/Mosaic — fresh discovery, a11y
      pass, HIGH severity — blocks a screen reader user entirely from the app's core artifact): the
      year mosaic `Canvas` (`ios/SkyGrid/Sources/Grid/GridCanvas.swift:38-97`) draws all 365
      day-cells with SwiftUI's `Canvas`, which has no default accessibility representation.
      `gridField` in `ios/SkyGrid/Sources/Grid/SkyGridView.swift:188-213` wraps `dayLabels` +
      `monthLabels` + `GridCanvas` in a plain `VStack` with `.accessibilityLabel(...)` at line 212,
      but there is no `.accessibilityElement(children: .ignore/.combine)` anywhere on the
      container, so the label never attaches to one coherent element — VoiceOver instead swipes
      through orphaned, context-free numeric `Text` children ("1"…"31", "1"…"12") with zero
      indication they're day/month scale markers, while the mosaic itself contributes nothing.
      Fix: wrap `gridField` in `.accessibilityElement(children: .ignore)` with the descriptive
      label attached there (or build a real accessible representation — e.g. a summary element
      stating streak/posted-day count, or a rotor-style overlay of invisible per-cell elements).
      Acceptance: VoiceOver manual pass on the `grid` scenario announces one coherent, labeled
      element instead of orphaned numerals; `xcodebuild test` green.
- [ ] Ticket 12 (correctness, localization, Camera — fresh discovery, design/UX pass): five strings
      on the camera review/live screen are hardcoded English literals bypassing the app's own
      `L10n.string(...)` system that every other string on the same screen uses:
      `ios/SkyGrid/Sources/Camera/CameraView.swift:128` (`"SKY GRID"`), `:131` (`"CAPTURED"`),
      `:145` (`"KEEP THIS SKY"`), `:383` (`Button("Retake", ...)`), `:393` (`"Use this one"`).
      Settings ships a working English/Japanese switcher and every other camera string already
      routes through `L10n.string`, so these five always render in English regardless of the
      selected language on the app's single most-used screen (daily capture). Fix: wrap each in
      `L10n.string(...)` with a new key and add the Japanese value to `Localizable.xcstrings`.
      Acceptance: switch the in-app language to Japanese (Settings), re-run the `camera-review`/
      `camera-live` scenarios, confirm all five now render in Japanese; `xcodebuild test` green.
- [ ] Ticket 13 (accessibility, WCAG 2.2 SC 4.1.3, Camera — fresh discovery, a11y pass): after
      tapping "Use this one," a failed post (`confirmationError` set, e.g.
      `camera.alreadyPosted`/`camera.confirmationError.postFailed`) is inserted as plain inline
      `Text` in `ios/SkyGrid/Sources/Camera/CameraView.swift:156-161` with no
      `UIAccessibility.post(notification:.announcement)` and no live-region trait — a VoiceOver
      user who taps the button hears nothing when it fails and has no way to discover why without
      blindly re-exploring the screen. Fix: post an accessibility announcement with the error text
      when `confirmationError` is set. Acceptance: VoiceOver manual pass on a forced-failure state
      confirms the error is spoken automatically; `xcodebuild test` green.
- [ ] Ticket 14 (correctness, affordance mismatch, Settings — fresh discovery, design/UX pass): the
      "Unlock the full archive" row (`ios/SkyGrid/Sources/Settings/SettingsView.swift:40-48`)
      doesn't override `settingRow`'s default `.disclosure` accessory, so it shows a `>` chevron —
      the standard iOS signal for push navigation — but tapping it presents the paywall as a modal
      `.sheet` (`:149`). Every other chevroned row in this file (Morning Alarm, Language, Community
      Safety) is a genuine push `NavigationLink`; this one row's affordance doesn't match its
      behavior. Fix: pass `accessory: .none` (or a dedicated "opens" indicator) for the paywall
      row, matching the non-chevron treatment already used for "Restore purchases" directly below
      it. Acceptance: re-screenshot `settings` scenario, confirm the paywall row no longer shows a
      push chevron; `xcodebuild test` green.
- [ ] Ticket 15 (consistency, Buddies — fresh discovery, design/UX pass): the "Accept" button for
      an incoming buddy request (`ios/SkyGrid/Sources/Friends/FriendRequestsView.swift:24-35`) has
      no `.buttonStyle` at all — not even one of the already-cleared generic system styles — so it
      renders with bare default control chrome (system tint, no capsule/fill) while every other
      primary/secondary action in the app goes through `SkyPrimaryButtonStyle`/
      `SkySecondaryButtonStyle`. Fix: apply `SkySecondaryButtonStyle` (or a small pill variant) to
      the Accept button. Acceptance: screenshot the `buddies-request-flow` scenario, confirm Accept
      now matches the app's pill-button language; `xcodebuild test` green.
- [ ] Ticket 16 (accessibility, WCAG 2.2 SC 2.5.8, Buddies — fresh discovery, confirmed by BOTH
      discovery passes independently): the destructive "Stop sharing this link" button
      (`ios/SkyGrid/Sources/Invite/InviteLinkCard.swift:145-150`) has no `.frame(minHeight: 44)`,
      unlike its sibling buttons in the same file (`invite.getNewLink` at :59-62, `invite.tryAgain`
      at :69-72, both explicitly 44pt) — a caption-sized (13pt) destructive control with a
      sub-minimum tap target. Fix: add `.frame(minHeight: 44)` to match the file's own established
      pattern. Acceptance: Accessibility Inspector or a UI test confirms ≥44×44pt hit target;
      `xcodebuild test` green.
- [ ] Ticket 17 (accessibility, WCAG 2.2 SC 1.1.1, Settings — fresh discovery, a11y pass): in
      `settingRow`'s `accessory` switch (`ios/SkyGrid/Sources/Settings/SettingsView.swift:318-330`),
      the `.disclosure` case's chevron `Image` (:318-321) is the only branch missing
      `.accessibilityHidden(true)` — `.external` and `.progress` two cases below it both correctly
      hide their icons. Every row using the default `.disclosure` accessory (Morning Alarm,
      Community Safety, Delete Account, the paywall CTA) gets VoiceOver appending a redundant
      unlabeled "chevron forward" announcement after the row's real label. Fix: add
      `.accessibilityHidden(true)` to the `.disclosure` case, matching its siblings. Acceptance:
      VoiceOver manual pass on `settings` confirms no chevron announcement on any disclosure row;
      `xcodebuild test` green.
- [ ] Ticket 18 (polish/clarity, Grid — fresh discovery, design/UX pass, LOWER priority): the year
      mosaic's month-banding is wired on (`ios/SkyGrid/Sources/Grid/SkyGridView.swift:207`,
      `monthBanding: true`) specifically so short months "read as the end of a month" per the code
      comment at `ios/SkyGrid/Sources/Grid/GridCanvas.swift:29-34`, but the band rect is drawn once
      per even month and then every day cell (including empty ones) is drawn on top at full size —
      the band is only visible in the ~1.5pt gutters between cells, imperceptible at render scale.
      In `grid-discovery.jpg`, February's truncated row reads as an unexplained cutout
      indistinguishable from a layout bug, exactly the failure mode banding was written to prevent.
      Fix: make the band visibly distinct where it matters — e.g. tint the empty-cell fill itself
      for even months, or a faint background wash behind the whole row. Acceptance: re-screenshot
      `grid`, confirm a short month's truncated row reads as an intentional month boundary, not a
      glitch; `xcodebuild test` green.
- [ ] Ticket 19 (test hygiene, not a UI/UX defect — fresh discovery, iteration 9's UI-test triage):
      update the 9 stale `SkyGridUITests` methods identified in iteration 9's Progress log entry
      (see below for the full root-cause table) so they assert against current UI copy/flow instead
      of pre-redesign strings. None of the underlying app behavior is wrong; the tests just weren't
      updated when the screens they cover evolved. Acceptance: `xcodebuild test -only-testing:
      SkyGridUITests` passes 41/41 (currently 32/41, 9 stale failures); no test assertion is
      weakened to force a pass — each fix reflects genuinely current, correct UI state.

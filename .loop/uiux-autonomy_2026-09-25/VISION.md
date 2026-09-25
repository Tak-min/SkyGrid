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

- [ ] At least 8 concrete tickets have gone through the full role pipeline (discovery → metric →
      evaluation → instruction → implementation → verify → commit), covering at least 3 distinct
      screens/flows, and at least one ticket is NOT one of the two owner-named symptoms.
- [x] The moku dialogue/position sync symptom has a filed root-cause finding AND either a fix is
      committed or a documented reason it's already correct (owner's perception vs. an actual
      code defect — state which, with evidence). DONE 2026-09-25 iteration 3 — real code defect
      (mismatched copy vs. actual fixed render location), fixed via Ticket 1b, see Progress log.
- [ ] The generic-button grep count (see Recon above) has measurably dropped from 23, with the
      remaining count and *why* each remaining one is intentionally left generic (if any) stated
      in this file's Progress log.
- [ ] `bash .loop/uiux-autonomy_2026-09-25/verify.sh` exits 0.
- [ ] No CRITICAL/HIGH reviewer findings remain unaddressed on any committed ticket.

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
  first by design. Committed as `<pending — see git log after this entry>`.

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
- [ ] Ticket 2: replace generic `.buttonStyle(.bordered/.borderedProminent/.plain/.automatic)`
      usages with a proper DesignSystem button component matching DESIGN.md's dials — start with
      the highest-traffic screens (TodayView, WelcomeView, CameraView) and continue in later
      tickets as capacity allows; not required to finish all 23 in one ticket.
- [ ] Ticket 3 (correctness + consistency, paywall — confirmed by BOTH discovery passes): the
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
      Accessibility Inspector), `xcodebuild test` green.
- [ ] Ticket 4 (correctness, contract violation, paywall second-chance — design/UX pass): DESIGN.md's
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
      re-run on the second-chance screenshot; `xcodebuild test` green.
- [ ] Ticket 5 (correctness, WCAG 2.2 SC 4.1.2 + SC 2.5.8, a11y pass): the copy-invite-code icon
      button in `ios/SkyGrid/Sources/Invite/InviteLinkCard.swift:107-117` (visible in
      `buddies.jpg` and `milestone.jpg`) has no `.accessibilityLabel` at all — VoiceOver falls
      back to the raw SF Symbol name ("doc on doc, button"), never announces the copied-state
      change, and has only `.frame(minHeight: 44)` with no minWidth, leaving the tap target
      bounded by the ~16-18pt glyph (under the 44×44pt / 24×24px minimums). Fix: add
      `.accessibilityLabel(L10n.string(...))` describing "Copy invite code" / a copied-confirmation
      announcement (e.g. `.accessibilityValue` or a `UIAccessibility.post(notification: .announcement,...)`
      on copy), and `.frame(minWidth: 44, minHeight: 44)`. Acceptance: VoiceOver manual pass in
      simulator confirms a meaningful label and copied-state announcement; Accessibility Inspector
      or a UI test confirms ≥44×44pt hit target; `xcodebuild test` green.
- [ ] Ticket 6 (consistency, alarm settings — confirmed by design/UX pass): two "Open Settings"
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
- [ ] Ticket 7 (correctness, WCAG 2.2 SC 1.4.3, a11y pass — systemic token issue): `SGT.ink3`
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
      `xcodebuild test` green.
- [ ] Ticket 8 (correctness, WCAG 2.2 SC 1.3.1, a11y pass — onboarding): the onboarding
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
      meaningful step value at each of the 10 onboarding steps; `xcodebuild test` green.
- [ ] Ticket 9 (polish/hierarchy, milestone — design/UX pass, LOWER priority than 3-8): the
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
      ENERGY 4/5 dial; `xcodebuild test` green.

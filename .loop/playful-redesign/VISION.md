# VISION — Make every captured sky feel like a playable reward

> This is the anchor for the owner-directed 2026-09-05 Sol loop. It supersedes the prior
> "capture stays quiet" direction for this redesign only; it does not erase the older record.

## Goal

Rebuild SkyGrid around one animated causal loop:

`alarm -> framed camera -> sky capture -> mascot celebration -> pixel tile joins the mosaic -> buddy skies reveal`

The product remains a wake-up ritual whose core action is photographing the morning sky. The
closed buddy reveal is the immediate reward; the growing pixel-art mosaic is the durable reward.

## Product bet and metric

- Target metric: scheduled-alarm occurrences that reach a saved capture within 15 minutes /
  scheduled-alarm occurrences. Current value: **unmeasured**.
- Counterfactual: without this work, the daily capture has weak feedback and the causal loop stays
  split across Today / Sky Grid / Buddies navigation.
- Bet: a short mascot celebration, confetti, tactile motion, and visible mosaic insertion make the
  daily action more rewarding and increase repeat capture.
- Cheapest test: instrument the reward sequence, verify it in UI-audit scenarios, then compare a
  seven-day TestFlight cohort after release.
- Exit condition: shorten or remove daily celebration layers if median capture completion time
  worsens by 20% or more; retain the pixel insertion if users still reach it reliably.

## Definition of Done (STOP CONDITION)

The loop succeeds only when all are objectively true:

- [x] `DESIGN.md` records the new owner-approved playful direction and explicitly supersedes the
      old mascot/confetti prohibition without deleting its history.
- [x] The general-purpose home `TabView` is removed from the primary daily flow; archive, buddies,
      alarm, and required settings/safety actions remain reachable contextually.
- [x] The camera uses the latest downloaded Locket-style reference
      (`/Users/taku8/Downloads/refero.design Locket Widget.jpg`): black stage, large inset rounded
      viewfinder, prominent shutter, compact surrounding controls. It is not a full-screen preview.
- [x] SkyGrid has one original sky/pixel mascot with a coherent visual role across at least the
      pre-capture and post-capture states; it does not copy PostHog's hedgehog or another app IP.
- [x] Every successful capture triggers one bounded celebration sequence with mascot motion,
      confetti, success haptic, and a Reduce Motion equivalent.
- [x] The captured photo visibly transforms into a deliberately pixelated tile and lands in the
      current mosaic before the reward sequence completes.
- [x] Buddy reveal remains server-authoritative and private; no animation exposes a photo before
      the existing reveal gate permits it.
- [x] Analytics can distinguish reward started/completed/reduced-motion without PII, and the
      existing capture event remains exactly-once per successful publish.
- [x] Fresh UI-audit screenshots cover the main pre-capture, framed camera/review, reward, mosaic,
      and buddy-reveal states at iPhone 17 size.
- [x] Focused tests, full `SkyGridTests`, Debug build, and Release build pass; independent root review
      finds no CRITICAL/HIGH issue.

## Constraints / guardrails

- Maximum 20 Sol iterations; stop after the same gate failure three times.
- One smallest verifiable step per iteration. A red gate is always the next step.
- No Firebase deploy, App Store submission, push, production write, schema migration, or destructive
  cleanup.
- Preserve camera permission/failure exits, account deletion, report/block, purchase restore, and
  accessibility paths even when they leave the primary visual flow.
- Preserve raw sky photos for buddy viewing. Pixelation is a derived mosaic presentation, not a
  destructive replacement of stored originals.
- Respect VoiceOver, Dynamic Type where text is present, and Reduce Motion.
- Do not modify the stopped legacy `.loop` logs/state or unrelated `videos/` work.
- Follow root `AGENTS.md`; stage or commit explicit paths only, never `git add -A`.

## Reference observations

- Latest downloaded reference is actually PNG data at 1125x2436 despite its `.jpg` suffix.
- Its reusable geometry is an inset rounded live preview on a black stage, large central shutter,
  compact social/status controls above, and history/status below.
- Do not reproduce Locket branding, yellow accent, friend-count chrome, or exact icon arrangement.
- The primary motion must explain state: capture becomes tile, tile joins mosaic, allowed buddy
  photos reveal. Decorative motion cannot obscure those events.

## Recon findings

- Runtime shell: `ios/SkyGrid/Sources/App/RootView.swift` owns the current three-tab `TabView`,
  camera full-screen cover, milestone cover, paywall, and settings navigation.
- Camera: `Camera/CameraView.swift`, `CameraPreviewView.swift`, `ShutterButton.swift`.
- Post-capture arbitration: `App/PostCaptureMomentPolicy.swift`, `Milestone/MilestoneView.swift`,
  `StreakSignal`, `RevealSignal`.
- Mosaic: `Grid/GridCanvas.swift`, `Grid/SkyGridView.swift`, `Grid/GridArchiveView.swift`.
- Buddy privacy: `Today/TodayViewModel.swift`, `Today/BuddyTile.swift`, Firestore rules. Visual work
  must consume reveal state and must not infer permission.
- Existing motion/tokens: `DesignSystem/ViewModifiers.swift`, `Theme.swift`, `Haptics.swift`.
- Existing capture analytics: `Publishing/CaptureAnalytics.swift`, emitted by `PostPublisher`.
- UI audit scenarios live in `App/SkyGridApp.swift`; current harness includes camera review/failure
  and milestone scenarios but needs explicit reward/pre-capture coverage for this redesign.

## TODO / progress

- [x] Iteration 1: freeze the new design system and mascot/reward motion contract in `DESIGN.md`.
- [x] Iteration 2: add the original mascot implementation and deterministic preview states.
- [x] Iteration 3: rebuild camera composition from the downloaded inset-viewfinder reference.
- [x] Iteration 4: implement the bounded daily reward state machine, confetti, haptic, and analytics.
- [x] Iteration 5: implement photo-to-pixel-tile transformation and mosaic landing motion.
- [x] Iteration 6: replace primary tab navigation with the unified daily/mosaic experience while
      preserving contextual access to archive, buddies, alarm, settings, and safety.
- [x] Iteration 7: connect server-authoritative buddy reveal to the reward sequence.
- [x] Iteration 8: add/refresh audit scenarios and screenshots.
- [x] Iteration 9: run full validation, resolve review findings, and write the dev-note.
- [ ] **Bug (owner-reported 2026-09-06): Day-1 capture freeze — Moku's reward overlay races the
      Day-1 milestone cover and the app becomes stuck, unable to proceed.** Root cause found by a
      Claude Code session (not yet fixed): `RootView.resolvePostCaptureMoment` guards against
      presenting a milestone while the camera or paywall is showing (`guard !showCamera,
      !showPaywall, milestoneMoment == nil else { return }`), but has **no guard for
      `rewardMoment != nil`**. If `streakSignal.reading` changes (the async streak arrives) while
      Moku's reward `fullScreenCover` is still on screen, this function proceeds anyway and can set
      `milestoneMoment`, so SwiftUI ends up asked to present two `fullScreenCover`s from the same
      view at once — Day 1 is hit most often because it's the very first milestone anyone reaches,
      right after the reward that always fires on a successful capture. Fix: add `rewardMoment ==
      nil` to that guard (mirroring how milestone/paywall already defer to each other), and make
      sure the deferred milestone still gets a chance to present from `rewardMoment`'s own
      `onDismiss` (it already calls `resolvePendingPresentations`, so this may be all that's
      needed) — verify with a real Day-1 capture in the Simulator, not just a unit test, since this
      is a UIKit-presentation-timing bug that a pure logic test can miss.

### Iteration evidence

- Iteration 1: `DESIGN.md` now marks the playful direction as owner-approved, preserves the prior
  draft under a superseded-history heading, and fixes the Moku visual/state contract, 24x24 derived
  pixel-tile baseline, 1.4-1.8 second reward sequence, daily bounded confetti, success truth gate,
  server-authoritative buddy reveal boundary, and Reduce Motion equivalent. Verified with
  `git diff --check -- DESIGN.md` and focused contract-term inspection on 2026-09-05.
- Iteration 2: added the code-native 4x4 Moku silhouette with six causal states, success-only
  captured-sky colors, Reduce Motion behavior, a deterministic debug gallery, and a `moku`
  UI-audit route. Verified on 2026-09-05 with all `SkyGridTests` passing, including the three
  `MokuViewTests`, a successful Debug simulator build, `git diff --check`, and an iPhone 17
  simulator screenshot of all six rendered states.
- Iteration 3: this iteration was left uncommitted by the prior Codex session when it hit its
  usage-limit wall (`CameraStage.swift`, the `CameraStageLayoutTests.swift` file, and a
  `CameraView.swift`/`ShutterButton.swift`/`SkyGridApp.swift` rework existed on disk but the new
  files were **not registered in `project.pbxproj`**, so the app did not build:
  `xcodebuild build` failed with "cannot find 'CameraStage' in scope"). Resumed by Claude:
  added the missing `PBXFileReference`/`PBXBuildFile` entries and group/Sources-phase membership
  for both new files (mirroring the existing `MokuView.swift`/`MokuViewTests.swift` pattern),
  removed one stray orphaned rationale comment left mid-file, and independently re-verified
  rather than trusting the prior session's uncommitted state. `CameraStage` extracts the shared
  black-stage/inset-viewfinder/centered-shutter geometry (`CameraStageLayout`, capped at 430pt
  wide, 54% of safe height) used by the live viewfinder, the review screen, and both UI-audit
  fixtures (`camera-live`, `camera-review`), replacing the old full-screen edge-to-edge preview.
  Verified: `xcodebuild build` succeeds, `xcodebuild test` passes all 272 `SkyGridTests`
  (269 pre-existing + 3 new `CameraStageLayoutTests`), and a real iPhone 17 Simulator screenshot
  of the `camera-live` UI-audit scenario
  (`screenshots/ui-audit-camera-live-inset-viewfinder-after.png`) confirms the black stage, inset
  rounded viewfinder, and centered shutter with Moku/live-swatch flanking it, matching the
  reference geometry (not its Locket branding). Reduce Motion is respected on both the shutter
  and review-choice press animations (`accessibilityReduceMotion` gates `SGMotion.press` /
  `.easeOut`). Note for later iterations: Moku at 64pt in the capture controls reads as a
  minimal pixel-grid mark, not yet a legible "creature" — acceptable for this composition step,
  but worth a second look once the reward-sequence work (Iteration 4) puts Moku in motion.
- Iteration 4: resolved the "known risk" left by Iteration 3's note without reusing
  `PostCaptureArming`/`StreakReading` — that pattern answers a different, genuinely-async
  question (does a milestone/paywall apply), which is why it needs an observe-and-re-ask
  listener. The reward's truth gate is simpler and already exists: `RootView.cameraSheet`'s
  `onConfirmed` closure already `await`s `services.postPublisher.publish(draft)` and only then
  calls `Haptics.postCompleted()`/`CaptureAnalytics.record` — i.e. publish success is already
  known synchronously at that call site, not behind a second async listener. `armDailyReward`
  hooks there directly: `DailyRewardPolicy.shouldPlay` (new, pure, tested) bounds it to at most
  once per successful post via a new `LocalDefaults.lastRewardPlayedLocalDate` guard (folded
  into `resetAutomaticPaywallState()` so an account switch on the same calendar day can't
  inherit another account's played-reward flag), then arms `pendingReward`. `pendingReward` is
  presented as `rewardMoment` from `showCamera`'s own `onDismiss` — mirroring the
  milestone/paywall pattern's reason for deferring to `onDismiss` (presenting a new full-screen
  cover from the same runloop as this one's dismissal animation can swallow it) — and takes
  that slot ahead of `resolvePendingPresentations`, so the reward can never be dropped or race a
  second competing full-screen celebration; `resolvePendingPresentations` (milestone/paywall)
  now runs from the reward cover's own `onDismiss` instead, deferred but never lost.
  New: `RewardBeat` (the five-beat timeline from DESIGN.md's motion contract, pure and tested —
  beats `.pixelDerivation`/`.mosaicLanding` are correctly sequenced but intentionally render
  nothing of their own yet; their visual transform is Iteration 5's job), `RewardSequenceController`
  (an `@Observable` state machine that fires `RewardAnalytics.record(.rewardStarted/.rewardCompleted,
  reducedMotion:)` and `Haptics.rewardLanded()` exactly once each per playback, and cancels
  cleanly without claiming completion if the view disappears mid-sequence), `ConfettiView` (a
  deterministic, seeded, one-shot burst of 24 squares sampled from the capture's `SkyColor` plus
  the existing `MokuColor.dawnSpark`/`.cloud` tokens — widened from `private` to internal rather
  than duplicating their hex values), and `RewardOverlayView` (composes Moku's existing
  bracing/delight/settled poses with the confetti burst, a static-halo Reduce Motion equivalent
  per DESIGN.md's accessibility section, and one settled-state VoiceOver announcement). Added
  `Haptics.rewardLanded()` with a doc-comment update clarifying it must never stack with
  `postCompleted`'s press feedback, per the motion contract's "do not stack multiple success
  haptics" rule. Buddy-reveal count is not yet wired into the VoiceOver announcement or the
  settle beat — that connection is explicitly Iteration 7's job, so the announcement only
  claims what this iteration can verify ("Sky saved").
  Verified: `xcodebuild build` succeeds (Debug and Release/`generic/platform=iOS`), `xcodebuild
  test` passes all 280 `SkyGridTests` (272 pre-existing + 3 new `DailyRewardPolicyTests` + 5 new
  `RewardBeatTests`), and `xcodegen generate` was re-run after adding the new source and test
  files so `project.pbxproj` registration didn't repeat Iteration 3's build-breaking gap. No new
  UI-audit fixture or screenshot yet — deliberately deferred to Iteration 8, since the reward's
  two placeholder beats would otherwise need a second screenshot pass once Iteration 5 fills
  them in.
- Iteration 5: the reward now freezes the already-persisted local square thumbnail at the same
  successful-publish truth gate and derives a disposable 24×24 logical-pixel `UIImage` from it.
  `RewardMosaicLandingView` first renders that real crop, switches to nearest-neighbour pixel
  samples at the pixel-derivation beat, and moves the tile into its stable local-date mosaic slot
  before the haptic/confetti peak. Its other cells remain neutral rather than fabricating prior
  skies; the raw full photo, thumbnail file, Storage path, and all buddy reveal/read rules remain
  untouched. When local thumbnail bytes are unexpectedly unavailable, the landing remains visibly
  marked with the already-recorded sky color but never invents an image. Reduce Motion reaches the
  same landed tile via the existing 200 ms controller path without spatial travel. Verified on
  2026-09-06: `xcodegen generate` registered both new Swift files, focused
  `PixelSkyTileRendererTests` passed (2 tests), and Debug `xcodebuild build` succeeded. The
  closed gate was run and is red only because 12 broader Definition-of-Done / later-iteration
  checklist items remain; it did not run builds by design after finding those unchecked items.
- Iteration 6: removed the production and DEBUG UI-audit `TabView` shells. `RootView` now keeps
  its existing single `NavigationStack` and all full-screen-cover/sheet arbitration intact, with
  `TodayView` as the only root and an explicit `HomeDestination` push for the archive or buddies.
  The daily page adds an accessible "Your mosaic" route and the toolbar adds the same two routes;
  the existing direct Morning Alarm `NavigationLink` remains in Today, and the existing Settings
  push still contains purchase restore, Community & Safety/unblock, Apple account backup, support,
  and account deletion. `BuddiesView` itself is unchanged, preserving its relationship, report,
  and block paths. Camera and buddy-push routes now pop those contextual destinations back to the
  daily root, preserving the former selected-Today behavior without inferring a buddy reveal. The
  `-SkyGridLaunchGrid` audit/deep-launch flag remains a one-shot archive push. Removed the old tab
  bar's 128pt bottom gaps. Verified on 2026-09-06: source contains no `TabView`, `git diff --check`
  passes, and Debug `xcodebuild build` succeeds. A first run failed only because the DEBUG audit
  host's `.tint` modifier was attached to an `if` result after the TabView removal; moving it to its
  `NavigationStack` made the next build green.
- Iteration 7: `RewardOverlayView` now receives the existing `RevealSignal` and reads a new pure
  `RewardRevealPolicy`, which returns a nonzero count only when the reading's local date exactly
  matches the just-saved capture. That source count is produced only by `TodayViewModel` statuses
  whose `.posted` post read was already permitted by Firestore rules; a stale date, absent reading,
  notification, local capture, or failed read remains zero. At settlement, only those existing
  `.posted` statuses appear via the existing `BuddyTile` (which independently gates thumbnail bytes
  on `.posted`), and VoiceOver names the verified count only when nonzero. Sealed/not-yet statuses
  and photo-fetch failure stay truthful; no new image fetch or reveal decision exists in Reward.
  Verified on 2026-09-06: `xcodegen generate` registered the two new source and test files, and
  focused `RewardRevealPolicyTests` passed (2 tests). The first focused run had one compile error
  from omitting `BuddyStreakDisplayPolicy`'s required `buddyName`; after passing the existing
  display name and fixed capture date, the next run was green.
- Independent re-verification (2026-09-06, Claude, after handing Iterations 5-7 to a separate
  Codex `exec` session per owner instruction): re-ran `xcodebuild build` (Debug) and
  `xcodebuild test` from clean, independently of Codex's own reports — build succeeded, all 284
  `SkyGridTests` passed (280 prior + 4 new: `PixelSkyTileRendererTests`, `RewardRevealPolicyTests`).
  Read the `RootView`/`TodayView`/`Reward*` diffs for commits `ff9f405`, `9b43799`, `7f0024f`
  directly rather than trusting the commit messages: the TabView removal preserves every exit path
  (archive/buddies via an "Explore" toolbar menu, Settings/alarm/purchase-restore/account-deletion/
  report-block unchanged), and the buddy-reveal reward strip reuses `BuddyTile`'s existing
  `.posted`-gated rendering and a same-day-only `RewardRevealPolicy` check rather than inventing a
  new visibility decision — no privacy regression found. Took a real iPhone 17 Simulator screenshot
  of the new Today home (`-SkyGridUIAuditScenario today`) confirming the tab bar is gone and the
  "YOUR MOSAIC" entry point renders correctly. Checked off the four Definition-of-Done items
  (camera reference, mascot, celebration sequence, analytics) that Codex's iterations had already
  satisfied in substance but left unchecked at the top-level checklist — confirmed each in code
  (`CameraStage.swift`, `MokuView.swift`, `RewardSequenceController`'s Reduce Motion branches,
  `RewardAnalytics`'s two no-PII events) before checking, not just deferring to the sub-iteration
  checkbox. Remaining before `verify.sh` goes green: Iteration 8 (refresh UI-audit screenshots for
  the reward/mosaic states) and Iteration 9 (full validation pass + dev-note).
- Iteration 8: added five deterministic, DEBUG-only `UIAuditScenario` reward fixtures — one for
  each `RewardBeat` — instead of racing the production 1.6-second controller. They compose the
  production pixel/mosaic/Moku/buddy views, hold the confetti burst at its deterministic seeded
  starting layout, never publish, and never emit analytics or haptics. The settled fixture supplies
  only a fixture `RevealSignal` with already-`.posted` statuses, so it exercises the same private
  `BuddyTile` gate rather than creating a second reveal decision. Added iPhone 17 UI tests which
  retain real Simulator attachments for all five reward beats plus today, live/review camera, grid,
  and buddies. On 2026-09-06 the two focused UI tests passed on iPhone 17 and their 1206×2622
  captures were saved as `screenshots/ui-audit-{today-home,camera-live,camera-review,grid,buddies}-playful-redesign-after.png`
  and `screenshots/ui-audit-reward-{capture,pixel,landing,peak,settle}-after.png`.
- Iteration 9: full `SkyGridTests` passed (284 tests / 51 suites) and the Release build succeeded.
  Independent review initially found two HIGH issues: two legacy UI tests still asserted the removed
  tab bar, and the reward could dismiss its settled state before Reduce Motion/VoiceOver users could
  perceive it. The tests now assert the contextual Buddies destination and its current Copy code
  action without a tab bar; the reward now holds its settled state for 400 ms, posts its explicit
  VoiceOver announcement, and resolves an interrupted overlay to settled without replay. The
  replacement focused UI tests passed. `dev-notes/playful-redesign-closeout_2026-09-06.md` records
  scope, evidence, and the still-unmeasured wake-to-capture completion metric.

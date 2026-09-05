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
- [ ] The general-purpose home `TabView` is removed from the primary daily flow; archive, buddies,
      alarm, and required settings/safety actions remain reachable contextually.
- [ ] The camera uses the latest downloaded Locket-style reference
      (`/Users/taku8/Downloads/refero.design Locket Widget.jpg`): black stage, large inset rounded
      viewfinder, prominent shutter, compact surrounding controls. It is not a full-screen preview.
- [ ] SkyGrid has one original sky/pixel mascot with a coherent visual role across at least the
      pre-capture and post-capture states; it does not copy PostHog's hedgehog or another app IP.
- [ ] Every successful capture triggers one bounded celebration sequence with mascot motion,
      confetti, success haptic, and a Reduce Motion equivalent.
- [ ] The captured photo visibly transforms into a deliberately pixelated tile and lands in the
      current mosaic before the reward sequence completes.
- [ ] Buddy reveal remains server-authoritative and private; no animation exposes a photo before
      the existing reveal gate permits it.
- [ ] Analytics can distinguish reward started/completed/reduced-motion without PII, and the
      existing capture event remains exactly-once per successful publish.
- [ ] Fresh UI-audit screenshots cover the main pre-capture, framed camera/review, reward, mosaic,
      and buddy-reveal states at iPhone 17 size.
- [ ] Focused tests, full `SkyGridTests`, Debug build, and Release build pass; independent root review
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
- [ ] Iteration 4: implement the bounded daily reward state machine, confetti, haptic, and analytics.
- [ ] Iteration 5: implement photo-to-pixel-tile transformation and mosaic landing motion.
- [ ] Iteration 6: replace primary tab navigation with the unified daily/mosaic experience while
      preserving contextual access to archive, buddies, alarm, settings, and safety.
- [ ] Iteration 7: connect server-authoritative buddy reveal to the reward sequence.
- [ ] Iteration 8: add/refresh audit scenarios and screenshots.
- [ ] Iteration 9: run full validation, resolve review findings, and write the dev-note.

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

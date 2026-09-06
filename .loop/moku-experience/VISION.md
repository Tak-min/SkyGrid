# VISION — Moku is one living companion, with immediate interaction

## Goal
Owner request 2026-09-06: rebuild onboarding and daily UI around expressive Moku motion and purposeful haptics, preserve the current adaptive visual identity, eliminate duplicate Moku and competing presentations, and reduce perceived waiting through local data and asynchronous work. Native iOS work, not a promotional video. Implementation direction explicitly requested: GPT-6 astra.

## Product bet and measurement
- Target: elapsed time from first onboarding appearance to first durably saved capture. Current value: unmeasured. Count all onboarding starts and report completion fraction alongside durations to avoid hiding abandonment.
- Counterfactual: reported competing presentations, disconnected static mascots, and loading gates remain.
- Bet: a single expressive companion makes progress legible and enjoyable without delaying interaction.
- Cheapest test: offline simulator onboarding-to-capture/presentation regression, real motion recording, local timing instrumentation; subsequently compare first-session completion duration and fraction in a real cohort.
- Exit: remove/shorten an effect if it blocks a control, worsens frame responsiveness, or increases median first-capture duration by 20% without improving completion.
- Existing social loop: capture → share sky mosaic/invite → recipient opens invitation → captures their own sky → mutual reveal → another morning. This pass prioritizes activation/return experience; referral sensitivity is unmeasured and no new sharing mechanism is justified. The shareable artifact remains a user's actual sky mosaic.

## Definition of Done
- [ ] One intentional Moku per primary scene; animated eyes/limbs and event-driven anticipation, leap and landing instead of whole-screen bobbing.
- [ ] Onboarding retains back/skip/free exits and a responsive primary action, with cohesive companion progression.
- [ ] Post-capture presentation has one owner, survives delayed streak/reveal signals, and remains dismissible; regression verified.
- [ ] Local cached display is available promptly; overlapping image work is coalesced and expensive decoding does not block UI. Privacy/cache revocation contracts preserved.
- [ ] Haptics correspond to user actions/landings, are reusable, bounded and suppressed for audits/inactive app state.
- [ ] First-experience timing instrumented without PII or audit events.
- [ ] Debug build, affected unit suite, and simulator UI regressions pass; light/dark/Reduce Motion inspected with real screenshots and motion evidence.
- [ ] Independent review has no unresolved high/critical findings; physical-device haptic quality explicitly unverified unless tested on device.

## Constraints
- Maximum 20 interactive iterations; stop on 3 identical no-progress failures and report concrete blocker.
- Preserve unrelated dirty files, previous loop records, existing photos, accounts, purchase/restore and private buddy access contracts.
- No deploy, push, production writes, schema migration, or device data reset.
- Follow project AGENTS.md; Xcode project comes from project.yml.

## Recon
- Entry: RootView owns multiple full-screen covers; old reward nil guard is present but owner still reports freeze, so reproduce rather than assume resolution.
- MokuView draws static eyes/limbs. MokuScreenMark repeats scale/y indefinitely. Today heading and empty hero both instantiate Moku.
- ThumbnailLoader synchronously reads/decodes local data per call; consumers include private buddy tiles, requiring revocation-aware design.
- Existing .loop/playful-redesign is completed historical work and contains unrelated dirty logs.

## Progress
- [x] Iteration 1: baseline, presentation/cache diagnosis, first-experience instrumentation.
- [x] Iteration 2: Astra character/onboarding implementation, build.
- [x] Iteration 3: presentation/waiting fixes and behavioral tests.
- [~] Iteration 4+: simulator critique, review corrections, final validation.

## Handoff 2026-09-06 (Codex usage limit -> Claude Opus 5)
Codex stopped mid-iteration on a rate limit, not on completion. Taken over and continued.

Verified by running, not by reading:
- Debug build green; unit suite 293/293 pass.
- UI suite 28 pass / 7 fail. The same 7 fail on a clean `git worktree` at HEAD, so they
  are pre-existing rot on the buddies surface, not a regression from this pass. They were
  left alone: unrelated surface, and fixing them is a separate decision.
- Light/dark/Reduce Motion inspected with real simulator screenshots (/tmp/sg-shots).

Corrections made on top of Codex's work:
- Camera live screen rendered TWO Moku (header mark + expressive one in the shutter row).
  Removed the header mark; verified in a screenshot.
- `Haptics.enabled` suppressed ALL haptics under Reduce Motion, silently regressing the
  shipped `postCompleted` confirmation for those users. Reduce Motion is not a haptic
  preference; character-play haptics stay gated at their own call site in `MokuView`.
- Welcome screen: the 3D-rotated mosaic projected past its layout bounds and collided
  with the "Tap Moku to say hello" caption — illegible in dark mode. Height now reserves
  the projected depth.
- `RootPresentationCoordinator` is fail-closed: only `didDismiss()` frees the lease. Added
  `releaseUnpresented()` plus a release when leaving `.today`, so a presentation that
  disappears without SwiftUI running `onDismiss` cannot block every later reward, paywall
  and invite. No such path is known today — this is defensive, and labelled as such.
- Folded the duplicated `as? DisplayImagePipeline ?? DisplayImagePipeline(remote:)` into a
  documented `DisplayImagePipeline.resolved(for:)`, stating why the throwaway wrapper is
  correct for offline stubs and unreachable from a shipped build.

Not obtained:
- Motion video evidence. `simctl io recordVideo` truncates to ~6s here regardless of the
  requested duration, so the leap was never captured end to end. The live-motion UI test
  (`testMokuPlayKeepsOnboardingActionUsable`) is the automated stand-in.
- Physical-device haptic quality: unverified, simulator only.

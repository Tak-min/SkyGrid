# VISION — Backlog Triage & AlarmKit Clarity (2026-09-24)

## Overview

A from-scratch small-scope loop following an Opus architecture review. That review did a cost/benefit analysis of the original backlog and ruled out nearly everything; only two tiny, low-risk items survived. This loop addresses them and closes them.

## Ground truth / verified facts (do not re-investigate these)

- **AlarmKit's iOS 26.1+ initializer `init(title:secondaryButton:secondaryButtonBehavior:)` does NOT accept a `stopButton` parameter** — Apple's SDK marks that property "not used anymore" / system-controlled. Source: `AlarmKit.framework/Modules/AlarmKit.swiftmodule/arm64e-apple-ios.swiftinterface` in the Xcode 26.5 SDK, lines ~55-65.
- **AlarmKit's iOS 26.0 initializer REQUIRES `stopButton` as a mandatory parameter** (same source, lines ~64-65). The app's minimum deployment target is iOS 17.0 (`project.yml:5`), so this branch is always compiled.
- **Consequence:** it is NOT possible to remove the alarm's stop control via code change on either OS branch — on 26.1+ the system already fully owns stop behavior (app cannot customize it further); on <26.1 removing `stopButton` breaks the build. This loop does NOT touch AlarmKit presentation or scheduling logic beyond adding explanatory comments.
- **Already implemented, no action needed:**
  - Multiple alarms (`MorningAlarmScheduler.swift:1038`, `scheduleAlarmKit(schedules:)`)
  - Pro value UI (`Friends/BuddyComparisonView.swift`, `Today/WeeklyRecapView.swift`)
  - Notification additions (`ios/functions/src/index.ts:781,860,913`, `Notifications/WeeklyRecapReadyScheduler.swift:9`)
  - Rest day (`Streak/RestDayPolicy.swift`)
- **Owner-deferred, no action:** post-capture mood/comment note (`PRODUCT-MODEL.md:138,155`).

## Definition of Done

All TODO checkboxes below are checked AND `verify.sh` (in this same folder) exits 0.

## TODO (use `- [ ]` checkbox format, in this order)

- [x] T0: Record the current HEAD commit sha into this folder's state.json as base_commit (84f0d8e433e89994d76d3683eaa239a94a1bf85a)
- [x] T1a: Add an explanatory comment immediately above the iOS<26.1 AlarmPresentation.Alert branch in ios/SkyGrid/Sources/Notifications/MorningAlarmScheduler.swift (~line 1016) citing that stopButton is a required parameter on this OS branch per AlarmKit.swiftinterface (iOS 26.0 initializer) — do not change any behavior, comment only (done by Codex, verified via `git diff`)
- [x] T1b: Add the same style comment above the second matching branch in the same file (~line 1274) (done by Codex, verified via `git diff`)
- [x] T1c: Update the comment at ios/SkyGrid/Sources/Notifications/MorningRealarmPolicy.swift lines 3-5 to describe the actual behavior: re-arms roughly every 5 minutes for up to 3 attempts, or until the 4-hour capture window ends (per MorningAlarmScheduler.swift:899-902) — replace the inaccurate "three-attempt" wording (done by Codex, verified via `git diff`)
- [x] T1d: In /Users/taku8/Desktop/SkyGrid/.loop/VISION.md around lines 151-154, add a strikethrough + correction note next to the stale claims ("single alarm time only", "standard stop button") pointing to the file:line evidence above. Do NOT use checkbox syntax for this note — it's a correction annotation, not a task. (done by Codex, verified via `git diff`)
- [x] T1e: Confirm `xcodebuild build -configuration Release` succeeds, then commit the T1 changes with explicit file paths (never `git add -A`) (Release build succeeded via Codex; `xcodebuild test -only-testing:SkyGridTests` independently re-run by main session 2026-09-25 — 354 tests passed; commit follows this edit)
- [ ] T2a: Compute SHA-256 for the 7 .caf files under ios/SkyGrid/Resources/Sounds/ and compare against the hash table in dev-notes/sound-design-sourcing_2026-09-11.md (~line 66); record match/mismatch result in this VISION.md
- [ ] T2b: If hashes MATCH (files untouched since that note), measure current loudness/peak per file and record it here. If hashes do NOT match, mark T2c and T2d below as "not needed — files already modified since baseline" and stop this branch of work.
- [ ] T2c: (only if T2b proceeded) Normalize each of the 7 files: true peak ≤ -1 dBTP, cross-file loudness spread ≤ ±2 LU, preserve original duration and format exactly; update the hash table in dev-notes/sound-design-sourcing_2026-09-11.md to the new hashes
- [ ] T2d: (only if T2c ran) Independently re-verify all 7 files decode correctly (afinfo exits 0) and re-measure loudness spread; commit with explicit file paths (never `git add -A`)

## Owner-confirmation items

Plain bullets, NOT checkboxes — these need a human on a real device, not something this loop can verify:

- Whether tapping the camera secondary button actually silences the alarm sound immediately — code comment at MorningAlarmScheduler.swift:1316-1317 and the 2026-09-05 decision record (line ~444) disagree on this.
- Whether pressing the OS-level stop control on iOS 26.1+ dismisses the alarm without opening the app.
- Whether the normalized sound effects (if T2c ran) actually sound right by ear.

## Explicitly out of scope for this loop

**Owner decision required, not a coding task:** making the alarm screen show only an "open app" button with no stop control at all. This conflicts with the platform constraint above AND with the owner's own prior decision records (`dev-notes/owner-selected-3b-5c-6c-decision-record_2026-09-05.md:319-357,441-453` and `dev-notes/interaction-benchmark_2026-09-07.md:53`, which required always keeping a normal stop path). The orchestrating session is asking the owner directly how to proceed on this; this loop must not attempt to implement it.

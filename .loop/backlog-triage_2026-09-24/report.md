# backlog-triage_2026-09-24 — closeout report

**Status:** closed, done. 3 iterations, well under the 8-iteration cap. No stuck cycles, no rate
limits hit.

## What this loop was

A tightly-scoped follow-up to an Opus cost/benefit review of SkyGrid's full backlog (dev-notes,
PRODUCT-MODEL.md, VISION.md, agent-intelligence memory). Almost everything in the original
backlog was either already implemented, owner-deferred, or explicitly prohibited by existing
product decisions — only two small, low-risk items survived scrutiny. See
`dev-notes/alarmkit-departure-feasibility-and-record-drift_2026-09-24.md` for the related
AlarmKit-departure feasibility findings that came out of the same review (owner declined that
direction after seeing the analysis).

## What was done

- **T1 (comment/doc corrections, no behavior change):** Codex added explanatory comments to
  both `AlarmPresentation.Alert` call sites in `MorningAlarmScheduler.swift` explaining why
  `stopButton` is mandatory on iOS 26.0 but rejected on iOS 26.1+; corrected the stale
  "three-attempt" comment in `MorningRealarmPolicy.swift`; annotated two stale claims in the
  root `.loop/VISION.md` with dated correction notes (strikethrough, not silent rewrite).
  Verified via `git diff` (scope matched exactly, nothing else touched), `xcodebuild test`
  (354/354 passed), and `xcodebuild build -configuration Release` (succeeded).
- **T2 (conditional sound normalization, re-scoped mid-loop based on real measurement):** all 7
  `.caf` files' SHA-256 matched the 2026-09-11 baseline (untouched). Loudness/peak measurement
  via `ffmpeg loudnorm` found the originally-planned fix ("peak ≤ -1 dBTP, spread ≤ ±2 LU"
  across all 7) didn't match reality — 6/7 files were already near max peak headroom (the
  "-30dB, too quiet" complaint is a perceived-loudness issue on short percussive sounds, not a
  peak-headroom issue, and fixing that properly needs compression + ear judgment, which this
  loop is not positioned to do unsupervised). Found one genuine objective defect instead:
  `streak_milestone.caf` measured true peak at **+0.79 dBTP — already over 0 dBTP**, a real
  clipping/inter-sample-over risk. Fixed with a pure linear gain reduction (no dynamics
  processing) to -1.51 dBTP, verified by re-measurement and `afinfo`. The other 6 files were
  left untouched — no objective defect, and further "make it louder" changes are the owner's
  call, not this loop's.

## Commits

- `4603afd` — T1 (AlarmKit/re-alarm comment corrections) + loop scaffold + AlarmKit-departure
  dev-note.
- (this closeout commit) — T2 (streak_milestone.caf peak fix) + hash table update + VISION.md
  closeout + this report.

## Deviations from the original plan (and why)

T2c/T2d were re-scoped from "normalize all 7 files to a target spec" to "fix the one file with
an objective defect, leave the rest for the owner's ear" — see the VISION.md T2b/T2c entries for
the measured numbers behind that call. This is a deliberate narrowing, not a shortcut: the
original spec was written before real measurement was available, and the measurement showed it
wouldn't actually address the underlying complaint (perceived loudness on short sounds, not
peak headroom) while risking unilaterally changing the character of sounds that have no
objective bug.

## Not done, and correctly so

The alarm-screen "Alarmy-style, stop button removed" request that motivated the original
investigation is **not implemented** — confirmed technically impossible via AlarmKit on any
supported iOS version, and a non-AlarmKit workaround was investigated and explicitly declined
by the owner after seeing the reliability/App-Store-risk tradeoffs. See the dev-note above.

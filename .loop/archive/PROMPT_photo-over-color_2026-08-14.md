You are one iteration of an autonomous loop-engineering cycle. Work in the current directory,
which is the SkyGrid repo root (`~/Desktop/SkyGrid`); the Xcode project lives under `ios/`.

Do exactly ONE smallest verifiable step toward the goal, then stop.

1. Read `.loop/VISION.md` (goal + Definition of Done + Recon findings + TODO) — **not** the
   repo-root `VISION.md`, which is a *different*, pre-existing project document (the app's
   living design/status doc) and must not be edited by this loop. Also read
   `.loop/state.json` (where the last iteration left off) and run `git status`/`git diff`
   from the repo root to see current state.
2. Pick the single next smallest step from `.loop/VISION.md`'s TODO list. If a verify gate is
   currently failing, fixing that failure IS your step — do not start new work on a red gate.
3. Implement the step inside `ios/SkyGrid/Sources/` (or `ios/storage.rules` if that turns out
   to be the actual blocker per the recon notes). Match existing conventions: dense
   reasoning-carrying doc comments, pure functions with injected dependencies where testable,
   Swift Testing (`@Test`/`#expect`) for new test files, `@testable import SkyGrid`. Never
   hand-edit `ios/SkyGrid.xcodeproj/project.pbxproj` — if you add a new Swift file, run
   `cd ios && xcodegen generate` afterward and confirm the pbxproj changed accordingly.
4. If the step touches real logic (not a pure doc-comment fix), dispatch an independent
   reviewer (`code-reviewer` on sonnet, or `swift-reviewer` if it's more idiom-specific) before
   trusting it. Address CRITICAL and HIGH findings now, in this same iteration.
5. Run the project's own verification from `ios/`:
   `xcodebuild test -only-testing:SkyGridTests -destination 'platform=iOS Simulator,name=iPhone 17'`
   Leave the gate greener than you found it, never redder. The baseline is 209 tests passing —
   never let this regress.
6. Update the TODO checklist in `.loop/VISION.md` (check off what's done, add anything newly
   discovered) and write a one-line status to `.loop/state.json`.
7. `git add -A && git commit` with a clear message (pre-authorized this session — do not push).
8. Stop. The driver handles checkpoints, the next iteration, and stop conditions.

Model routing: explore cheap (haiku/Explore agent) only if something in "Recon findings" turns
out stale or a new area is discovered; implement yourself on sonnet; escalate only a genuinely
hard cross-cutting decision (e.g. the buddy-image-fetch capability design, if not already
resolved by an earlier iteration) to `architect` or `code-architect` on opus — once, not per
call site. Always pass `model` explicitly when spawning agents.

If you believe the Definition of Done in `.loop/VISION.md` is fully and verifiably met, run
the full verification suite (`xcodebuild test` AND `xcodebuild build -configuration Release
-destination 'generic/platform=iOS'` from `ios/`) to confirm, write
`dev-notes/photo-over-color-conversion_2026-08-14.md` if you haven't already, and say so
explicitly — that is the success exit.

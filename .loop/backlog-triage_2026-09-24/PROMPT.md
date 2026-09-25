You are running one iteration of a bounded small-scope loop for backlog triage in
`/Users/taku8/Desktop/SkyGrid`. This loop has two tiny, low-risk items: clarifying AlarmKit
comments (T1a-T1e) and optionally normalizing sound files (T2a-T2d) if they are unchanged since
a baseline measurement. Read `.loop/backlog-triage_2026-09-24/VISION.md` in full first — it
holds the verified ground truth, the two items, the Definition of Done, and the TODO checklist.
Read `.loop/backlog-triage_2026-09-24/state.json` and `git log --oneline -5` for where the
previous iteration left off.

1. **Read VISION.md fully**, including ground truth and out-of-scope guardrails. This loop does
   NOT touch AlarmKit presentation or alarm-scheduling logic beyond specified comments, and does
   NOT change `MorningRealarmPolicy`'s interval/maximumAttempts/captureWindow values.

2. **Model routing for this step:**
   - **Swift/comment edits (T1a/T1b/T1c) and audio work (T2b-T2c)** go to Codex via the `codex`
     MCP tool — one bounded task per dispatch, explicit working directory `/Users/taku8/Desktop/SkyGrid`,
     explicit statement of what must NOT be touched (AlarmKit presentation/scheduling logic beyond
     the specified comments; `MorningRealarmPolicy`'s actual interval/maximumAttempts/captureWindow
     values).
   - **T0 (record commit sha), T1d (update root VISION.md), T2a (compute hashes), T2d (verify),
     running verify.sh, updating this VISION.md checkboxes, and commits** stay with the main
     orchestrating session (Sonnet), not Codex.

3. **No UI changes expected** in this loop, so the antislop skill / DESIGN.md read is not required
   — but note (from root PROMPT.md convention) that if any step ever affects visible UI, antislop's
   SKILL.md and DESIGN.md must be read first.

4. **Pick the next unchecked TODO** from VISION.md in order.

5. **Dispatch to Codex** if the step is T1a/T1b/T1c/T2b-T2c; otherwise **implement locally**.

6. **Run verify.sh** after each committed step (within `.loop/backlog-triage_2026-09-24/`):
   ```bash
   ./.loop/backlog-triage_2026-09-24/verify.sh
   ```
   
7. **Stop/stuck conditions:**
   - Halt if the same verify.sh result repeats 3 times consecutively (no progress).
   - Hard iteration cap is 8 (much lower than the root loop's 40, because scope is tiny).
   - If Codex or the main session hits a rate limit, set state.json status to "blocked_rate_limit"
     and halt immediately — this does NOT count toward the stuck counter.
   - If the Release build breaks during T1, immediately revert those specific changes and halt
     rather than attempting further fixes.

8. **Guardrails (inherit from root `.loop/PROMPT.md` plus additions):**
   - No `firebase deploy` of any kind
   - No `git add -A` — use explicit paths only
   - No manual edits to `ios/SkyGrid.xcodeproj/project.pbxproj` (use `xcodegen generate` if needed,
     though this loop should not need it)
   - No `git push`
   - No App Store Connect operations
   - Do not touch anything marked "Deferred" in the root `.loop/VISION.md`
   - Do not modify AlarmKit presentation or alarm-scheduling code beyond the specified explanatory
     comments
   - Do not change `MorningRealarmPolicy`'s interval/maximumAttempts/captureWindow values

9. **Update `.loop/backlog-triage_2026-09-24/VISION.md`'s TODO checklist** (check off what's done)
   and write a one-line status to `.loop/backlog-triage_2026-09-24/state.json`.

10. **Commit with explicit paths only:**
    ```bash
    git add ios/SkyGrid/Sources/Notifications/MorningAlarmScheduler.swift ...
    git commit -m "T1a/T1b: Add AlarmKit platform-branch comments per iOS26.0/26.1 SDK..."
    ```
    Never `git add -A`.

11. Stop. The driver handles checkpoints, the next iteration, and stop conditions.

If you believe every item in the Definition of Done is fully met, verify it once more:
- All `- [ ]` checkboxes in VISION.md are checked
- verify.sh exits 0
- git log shows the expected commits
- No untracked files remain in the working directory

Then and only then, halt and report success.

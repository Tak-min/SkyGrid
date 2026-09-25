You are running one iteration of a bounded autonomous UI/UX-quality loop in
`/Users/taku8/Desktop/SkyGrid`. Read `.loop/uiux-autonomy_2026-09-25/VISION.md` in full first — it
holds the goal, the Recon already done (don't re-derive it), the required per-iteration role
pipeline, the Definition of Done, guardrails, and the TODO/ticket list. Read
`.loop/uiux-autonomy_2026-09-25/state.json` and `git log --oneline -5` for where the previous
iteration left off.

1. Pick the next ticket from VISION.md's TODO in order (Ticket 0 first if unchecked). If a
   ticket is `blocked_on_asset` (see step 3f), skip it and pick the next one instead — do not
   wait for it. **Round 2 (owner instruction 2026-09-26):** the Definition of Done now has a
   Round 2 block requiring at least 2 of the next 8 tickets to come from a FRESH discovery pass
   (new screenshots/code reading of screens not yet audited — Settings, Camera, Buddies,
   Milestone, Grid/Mosaic, WeeklyRecap are untouched so far), not just draining the existing
   TODO backlog. Every ~3-4 tickets drained from the backlog, spend one iteration running a new
   Ticket-0-style discovery pass instead of implementing, and append what it finds.

2. **Run the role pipeline for that one ticket** (owner-mandated separation — do not collapse
   these into one pass):
   a. **Discovery** — dispatch a discovery pass (load `ios-design-agent-skill` guidance and
      `.loop/antislop/skills/antislop-ui/SKILL.md`; use `a11y-architect` for accessibility-shaped
      findings) over real Simulator screenshots from the UI-audit harness (`-SkyGridUIAudit
      -SkyGridUIAuditScenario <name>`, scenarios in `App/SkyGridApp.swift`'s `UIAuditScenario`).
      Model: sonnet. Output: concrete, file-referenced defects.
   b. **UX-metric-definition** — a SEPARATE agent dispatch (not the same call as 2a) turns the
      flagged dimension into one objective, locally-measurable number. Developer-side tooling
      only (Instruments, XCTest performance measurement, frame analysis of local recordings,
      manual timing scripts) — never propose shipped analytics/telemetry. Model: sonnet.
   c. **Evaluation** — a SEPARATE agent dispatch scores the current build against 2b's metric
      using real measurement, not a guess. Model: sonnet.
   d. **Improvement-instruction** — a SEPARATE agent dispatch turns 2c's finding into one bounded
      ticket: exact file(s), exact change, exact acceptance check. Model: sonnet.
   e. For Ticket 0 and Ticket 1 (already fully specified in VISION.md), steps 2a-2d may be
      lighter-weight (the ticket is already concrete) — still run discovery once for Ticket 0
      since its whole point is producing new tickets for the TODO list.

3. **Implementation:**
   a. Normal Swift/SwiftUI/asset-catalog work: dispatch to Codex via `mcp__codex__codex`, one
      bounded task per call, per `~/.claude/rules/ecc/common/codex-delegation.md` — state the
      working directory (`/Users/taku8/Desktop/SkyGrid`), the exact success criterion, and what
      must not be touched (no `firebase deploy`, no `git add -A`, no `ios/functions`,
      `ios/firestore.rules`, or hand-edited `project.pbxproj`).
      **Model routing (owner instruction, 2026-09-25):** if the ticket is a fully-specified,
      bounded packet with no architectural ambiguity (exact file(s), exact change, e.g. a single
      button-style swap or an asset-catalog wiring step) — pass `model: "gpt-5.6-luna"` explicitly
      (OpenAI's budget/volume Codex tier, treated the same way this harness treats
      `haiku-scoped-worker`: cheap, fast, exact scope). If the ticket needs judgment under
      ambiguity (moku-sync root cause, any shared DesignSystem API change, anything touching more
      than one screen's contract), leave `model` unset so Codex self-routes Terra/Sol.
   b. If this iteration has more than one independent ticket ready with disjoint file scopes,
      dispatch them to Codex **in parallel** (multiple tool calls in the same message) — this is
      the owner's "multiple parallel implementation agents" requirement; most of that parallel
      volume should be Luna-tier per 3a.
   c. Read every file Codex reports changing (Read/Grep, not just its own summary) before
      trusting the result — Codex's report is hearsay until checked.
   d. If the ticket touches visible UI (colors, layout, components, copy tone, composition):
      read `DESIGN.md` and `.loop/antislop/antislop.md` +
      `.loop/antislop/skills/antislop-ui/SKILL.md` first, pass the relevant excerpt into the
      Codex prompt (Codex does not read VISION.md automatically), and run the antislop-ui
      Delivery Gate (Purpose-Gate + Liveliness + Craftsmanship; skip web-only items) as a
      PASS/FAIL note in this iteration's Progress log entry before committing. A FAIL means fix
      it this iteration, not ship-and-note.
   e. If the ticket touches real logic, dispatch `swift-reviewer` or `code-reviewer` (sonnet)
      over the actual diff before trusting it. Address CRITICAL/HIGH findings now.
   f. If the ticket needs a NEW raster image asset that plain SwiftUI/SF Symbols cannot produce:
      do NOT attempt browser automation yourself in this headless iteration. Append one entry to
      `.loop/uiux-autonomy_2026-09-25/asset-requests.md` (what image, size/aspect, style
      reference, target asset-catalog slot), mark the ticket `blocked_on_asset` in VISION.md, and
      move on to a different ticket this iteration. A later iteration resumes it once
      `.loop/uiux-autonomy_2026-09-25/assets/<slot-name>.png` exists (the owner's interactive
      session fulfills these, not this driver).

4. Run `bash .loop/uiux-autonomy_2026-09-25/verify.sh` from the repo root. Note: the headless
   driver treats a zero exit from this script as "stop the whole loop, Definition of Done met" —
   this script is written to only exit 0 when VISION.md's Definition-of-Done checklist is fully
   checked AND the real xcodebuild gates pass, so a single green ticket does not falsely end the
   loop early.

5. Update `.loop/uiux-autonomy_2026-09-25/VISION.md`: append one line to the Progress log for
   this iteration (ticket worked, role outputs, PASS/FAIL notes, commit sha), check off the
   ticket in TODO if fully done, and append any newly-discovered ticket(s) from step 2a in
   priority order (correctness/consistency before polish).

6. Write a one-line status to `.loop/uiux-autonomy_2026-09-25/state.json`:
   `{"iteration": N, "status": "...", "last_ticket": "...", "verify_rc": ...}`.

7. **Commit with explicit paths only** (never `git add -A` — a concurrent session writes to
   `videos/joespov-skygrid-remix/`):
   ```bash
   git add <explicit paths you touched>
   git commit -m "..."
   ```
   Never `git push`, never `firebase deploy`, never touch App Store Connect.

8. Stop. The driver handles checkpoints, the next iteration, and stop conditions.

**Stuck/rate-limit handling:** if Codex or any dispatch hits a rate limit, set state.json's
status to `blocked_rate_limit` and stop this iteration immediately (does not count as a stuck
signature). If the same verify.sh output repeats, that is the driver's job to detect — just do
not paper over a red gate by weakening the gate itself.

If you believe the Definition of Done in VISION.md is fully and verifiably met, re-check: every
`- [ ]` in its Definition-of-Done block is actually checked with real evidence (not just claimed),
`verify.sh` exits 0, and `git log` shows the expected commits. Only then let verify.sh's zero exit
end the loop.

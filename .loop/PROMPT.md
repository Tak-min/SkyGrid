You are running one iteration of a bounded autonomous coding loop in
`/Users/taku8/Desktop/SkyGrid`. Read `.loop/VISION.md` in full first — it holds the goal, the
verified ground truth (do not re-derive facts already stated there), the Definition of Done, and
the TODO checklist. Read `.loop/state.json` and `git log --oneline -5` for where the previous
iteration left off.

1. Pick the **next smallest verifiable step** from the unchecked TODO items in `.loop/VISION.md`,
   in the order listed (research/assessment before visual design, before the buddy-model
   migration, before alarm/share/ASO work) — unless a dependency makes a different order
   obviously correct (e.g. don't start the N-way buddy UI before the architecture escalation item
   is checked off).

2. **Model routing for this step** (pass `model` explicitly on every Agent spawn):
   - The two items marked "Opus escalation" in VISION.md's TODO list are exactly that: dispatch
     `architect` or `planner` on **opus**, once per item, and reuse/continue that same escalation
     if a later iteration needs to refine it — do not re-run a fresh Opus pass per call site.
   - Design research (the 50-source pass) and general "where is X" recon: `Explore` on
     **haiku/sonnet** — have it return a tight source list + what was taken from each, not raw
     dumps. Use `WebSearch`/`WebFetch` directly for the actual reference gathering; do not
     fabricate sources.
   - **Normal implementation (Swift, SwiftUI, Firestore rules, Cloud Functions): delegate to
     Codex, not the main loop (owner instruction, 2026-09-05 — Codex is running in the owner's
     own separate terminal window specifically to own coding for this project).** Use
     `mcp__codex__codex` per `~/.claude/rules/ecc/common/codex-delegation.md`: one bounded task
     per call, state the exact working directory (`/Users/taku8/Desktop/SkyGrid`), the success
     criterion, and what must not be touched (no `firebase deploy`, no `git add -A`); never pass
     a model override — Codex routes Terra/Sol itself. The main loop's own role for this step is
     to pick the task, write the bounded prompt, and verify Codex's result — not to write the
     Swift/TypeScript itself.
   - Read every file Codex reports changing (Read/Grep, not just its own summary — codex's report
     is hearsay until checked) before running review or verify.
   - Independent review when the step touches real logic (not a pure doc/comment change):
     `swift-reviewer` or `code-reviewer` on **sonnet**, over Codex's actual diff. For the
     Firestore-rules/buddy-model migration specifically, also consider `security-reviewer` on
     **opus** once, given it's a privacy-boundary change.

3. Implement the step. Never invent unverifiable claims (a fake source, a fake metric, a
   "users will love this" line with no evidence) — if something is genuinely unmeasured, write
   `unmeasured` and say what the cheapest test would be, per the kernel's claim/bet discipline.

4. If the step touches real logic, dispatch the review agent from step 2 before trusting it.
   Address CRITICAL and HIGH findings now, in this same iteration.

5. Run `.loop/verify.sh` from the repo root (this is also the headless driver's `LOOP_VERIFY_CMD`
   — it fails while any VISION.md TODO item is unchecked, and only then runs the real
   `xcodebuild test` + Release `xcodebuild build`, both with explicit `-project`/`-scheme`, never
   piped through anything that could mask their exit code). Note: **the headless driver exits the
   entire loop the instant this script exits 0** — do not check off a TODO item, or leave the
   checklist all-checked, unless the work behind it is genuinely done; a false-green here stops
   the loop early on unfinished work, which already happened twice before this script existed.

6. Update `.loop/VISION.md`'s TODO checklist (check off what's done, add anything newly
   discovered — e.g. a sub-step the recon revealed) and write a one-line status to
   `.loop/state.json` (`{"iteration": N, "status": "...", "verify_rc": ..., "same_count": ...}`).

7. `git add <explicit paths you touched>` — **never `git add -A`**, this repo has a concurrent
   unrelated session writing to `videos/joespov-skygrid-remix/`. Commit with a clear message
   (pre-authorized this session — do not push).

   **Never run `firebase deploy` (any target) from this loop, ever, regardless of how green
   everything is.** Committing is pre-authorized; deploying to production is not, and cannot be
   granted to an unattended loop — see VISION.md's guardrails section. Backend work (Cloud
   Functions, Firestore rules) stops at "committed and verified," full stop.

   **Never act on anything in VISION.md's "Deferred to a future session" section** (currently: an
   App Store Connect listing fix) — it is plain bullets, not checklist items, specifically so it
   can never block `.loop/verify.sh`'s Definition-of-Done check; leave it exactly as-is.

8. Stop. The driver handles checkpoints, the next iteration, and stop conditions.

If you believe every item in the Definition of Done (`.loop/VISION.md`) is fully and verifiably
met, run `.loop/verify.sh` from the repo root to confirm (check its actual exit code), write the
final summary dev-note, and say so explicitly — that is the success exit, and it is also what
makes the headless driver itself exit 0.

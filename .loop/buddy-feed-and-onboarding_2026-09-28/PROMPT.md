You are running one iteration of a bounded feature-implementation loop in
`/Users/taku8/Desktop/SkyGrid`. Read `.loop/buddy-feed-and-onboarding_2026-09-28/VISION.md` in
full first — it holds the owner's direction for both tracks (buddy feed → vertical; onboarding →
quiz-funnel expansion with education content and real personalization effects), the Recon already
done, the Definition of Done for this Phase 1, and the TODO/ticket list. Read
`.loop/buddy-feed-and-onboarding_2026-09-28/state.json` and `git log --oneline -5` for where the
previous iteration left off.

1. Pick the next ticket from VISION.md's TODO in order. Track A (buddy feed) and Track B
   (onboarding) tickets touch disjoint files — if more than one ticket is ready with disjoint
   scope, dispatch them **in parallel** (multiple `mcp__codex__codex` calls in one message), per
   the owner's explicit parallel-dispatch authorization (2026-09-28).

2. **Implementation**: dispatch to Codex via `mcp__codex__codex`, one bounded task per call, per
   `~/.claude/rules/ecc/common/codex-delegation.md` — state the working directory, the exact
   success criterion, and what must not be touched (no `ios/functions`, no `ios/firestore.rules`,
   no hand-edited `project.pbxproj`, no N-way buddy-group data model work).
   **Model routing**: `OnboardingStep` enum/state-machine changes and the `BuddyRow` relayout
   (Tickets A1, B1, B2) are judgment calls — leave `model` unset, Codex self-routes Terra/Sol.
   Once B1's education-slide component exists, any FURTHER education-slide screen that just
   plugs in new copy/imagery into that established component (part of B3 and Phase 2) is a
   fully-specified, zero-ambiguity packet — dispatch those with `model: "gpt-5.6-luna"`,
   in parallel when several are ready.

3. Both tracks are heavily user-visible: read `DESIGN.md` (ENERGY 4/5 / RHYTHM 4/5 / MOTION 4/5
   register for this work, not the calm ExportTheme register) and
   `.loop/antislop/antislop.md` + `.loop/antislop/skills/antislop-ui/SKILL.md` first, pass the
   relevant excerpt into the Codex prompt, and run the antislop-ui Delivery Gate before
   committing. A FAIL means fix it this iteration, not ship-and-note.

4. **Content check (Track B only)**: before committing any new educational copy, re-read it
   against VISION.md's content constraint — no invented statistics, no medical/clinical framing,
   no named-study citations. If a screen's copy states anything that reads as a specific,
   falsifiable health claim, rewrite it to the same generic, uncontroversial register as the
   rest of the app's marketing copy (see `metadata/version/1.0.10/*.json` for the house voice)
   or cut the claim entirely — do not fabricate a source to justify it.

5. Read every file Codex reports changing (Read/Grep, not just its summary) before trusting it.
   Dispatch `swift-reviewer` (sonnet) over the actual diff before trusting it; address
   CRITICAL/HIGH findings in the same iteration.

6. Run `bash .loop/buddy-feed-and-onboarding_2026-09-28/verify.sh` from the repo root.

7. Update VISION.md: append one Progress log line (ticket, what changed, review outcome, commit
   sha), check off the ticket in TODO, append any Phase 2 tickets discovered along the way.

8. Write `.loop/buddy-feed-and-onboarding_2026-09-28/state.json`:
   `{"iteration": N, "status": "...", "last_ticket": "...", "verify_rc": ...}`.

9. **Commit with explicit paths only** (never `git add -A`):
   ```bash
   git add <explicit paths you touched>
   git commit -m "..."
   ```
   Never `git push`, never `firebase deploy`, never touch App Store Connect (1.0.11 is already
   submitted and awaiting review — this loop's work is for a future version).

10. Stop. The driver handles checkpoints, the next iteration, and stop conditions.

**Stuck/rate-limit handling**: if Codex or any dispatch hits a rate limit, set state.json's
status to `blocked_rate_limit` and stop this iteration immediately (does not count as a stuck
signature). If the orchestrating session itself (this `claude -p` call) is the one that's rate
limited, there is nothing to do about it from inside the iteration — the outer driver's own
no-progress detection handles that; do not loop retrying it yourself.

If you believe the Definition of Done in VISION.md is fully and verifiably met, re-check every
`- [ ]` is actually checked with real evidence, `verify.sh` exits 0, and `git log` shows the
expected commits. Only then let verify.sh's zero exit end the loop.

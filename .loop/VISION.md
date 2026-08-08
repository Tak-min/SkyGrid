# LOOP VISION — Sky Grid UI/UX repair + viral persona pivot

Started: 2026-08-08. Driver: `/loop-engineer`.
Scope is **iOS app UI only** (`ios/SkyGrid/Sources/`). The waitlist site, backend, Firebase
rules, and pricing are out of scope for this loop.

## Goal (from the requester, verbatim intent)

1. **Fix concrete UI/UX problems and points of friction** — without degrading the user
   experience that already works.
2. **Pivot the UI persona.** Today the app is deliberately "quiet, pale, ritual" (serif
   headlines, `#FAF7F2` warm white, ultralight numerals, no fixed brand colour, one haptic
   per session, explicitly "never resemble a social feed"). The requester wants the opposite
   direction: a UI built around **elements that spread virally on social media**.
3. Analyse the codebase autonomously; boot the simulator to experience the app where that
   is what it takes to find the problem.

## The conflict this loop must resolve deliberately

`VISION.md` §6 and the doc comments across the codebase encode a *founder-approved* quiet
ritual aesthetic. Examples that are explicitly load-bearing today:

- `TodayView.swift:3` — "the first five seconds never resemble a social feed or a dashboard"
- `Theme.swift:8` — "The app itself has no fixed brand color"
- `dev-notes/motion-polish-pass_2026-08-02.md` — new haptics rejected as "演出過多"

The new instruction supersedes this for the *persona*, not for the *product*. The loop's
working principle:

> **Keep the ritual as the private core; make the artifact loud.**
> The morning capture stays calm (it happens at 6am, half-awake — a loud UI there is
> hostile). Everything that is *seen by other people* — the share card, the grid, the
> streak, the buddy surface, milestone moments — becomes bold, high-contrast, screenshot-
> bait, and explicitly designed to be posted.

Anything that would make the 6am capture flow harder or noisier is out of bounds.

## Definition of Done

The loop halts successfully when **all** of the following hold:

- [ ] D1. `xcodebuild` build for the iOS simulator succeeds with 0 errors, and the test suite
      shows **no new failures against the measured baseline**. Baseline taken 2026-08-08 12:58
      JST *before* any change by this loop: **144 passed / 4 failed / 5 skipped**. The 4
      failures are pre-existing (3 are `signal kill` simulator crashes; 1 is the grid-unavailable
      UITest landing on the real startup-failure screen because of the App Check 403). An
      absolute green is therefore not achievable in this environment and is not the gate.
- [ ] D2. A written UI/UX audit exists at `.loop/audit.md` grounded in **actual simulator
      screenshots**, not prose speculation — each finding names a file:line.
- [ ] D3. Every CRITICAL/HIGH finding from that audit is either fixed or has a recorded
      reason for deferral.
- [ ] D4. The viral persona is present in the app in a way a user can see: at minimum the
      share artifact, the grid/streak surface, and one milestone moment are visibly bolder
      than the current pale-neutral treatment, and the share card carries the install link.
- [ ] D5. An independent reviewer subagent (`swift-reviewer` / `code-reviewer`) has passed
      the diff with no unresolved CRITICAL/HIGH findings.
- [ ] D6. A dev-note recording thought log + gotchas is written to
      `dev-notes/ui-viral-persona-pass_2026-08-08.md` (machine mandate).

## Out of bounds (do not do these)

- No pricing / paywall monetisation changes (requester's exclusive call, and pricing was
  just settled 2026-08-08).
- No fake social proof — no invented user counts, streak leaderboards with fabricated
  people, or fake "N people posted today" (memory: `feedback-decline-fake-social-proof-counts`).
- No GO/NO-GO or pivot decisions about the product itself.
- No `git push`, no App Store submission, no deploy. Commits are allowed as checkpoints.
- Do not make the 6am capture flow louder or add friction to it.

## Known context carried in (do not re-derive)

- App is **already live** on the App Store since 2026-08-06 (id6796222704), 0 ratings.
- A concurrent Claude session earlier today shipped v1.0.1 (build 3) to ASC: review prompt
  (`AppReviewPromptPolicy.swift`) + share-card QR code (`QRCodeGenerator.swift`). Those are
  uncommitted in the working tree. **Build on top; do not revert them.**
- The working tree already has ~84 uncommitted files from that session. Keep this loop's
  changes reviewable against that baseline.
- Buddy invites are handle-match only; there is no invite link / deep link (known gap,
  requester's design call — do not unilaterally build the invite-reward economy).

## Recon findings

(filled in by Phase 1)

## Iteration log

(appended each iteration)

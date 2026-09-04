# Claude Code ⇄ Codex parallel loop — handoff log

Mode (pivoted 2026-09-04): Claude Code no longer implements SkyGrid code. Each turn, Claude Code
hands **one** problem + abstracted improvement proposal to the Codex CLI session running in a
separate terminal window (tty varies by relaunch; found via `tty of tab` in Terminal.app, title
contains "codex"). Codex independently verifies against the live codebase and implements. Claude
Code checks Codex's report each cycle (via `screencapture -D2` + crop, since Codex's TUI uses the
terminal's alternate screen buffer and `contents of tab` cannot read it as text) and produces the
next finding informed by what Codex already covered — never resend something Codex has verified
fixed or explicitly rejected with a reason.

Handoff mechanism: write finding to a scratch file, `pbcopy` it, focus the Codex Terminal window
(`cliclick` at the input box using that window's AppleScript `bounds`, converting local screenshot
coords to global coords via the window's own bounds — do not assume screencapture's display-local
coordinates equal global coordinates on a multi-monitor setup), Cmd+V to paste (confirms as
"[Pasted Content N chars]"), then Return to submit. Always screenshot-verify the paste landed
before submitting.

---

## Batch 1 (sent 2026-09-04, ~11:03 JST)

Source: `dev-notes/virality-stickiness-assessment_2026-09-04.md` (Opus assessment from the earlier
implementation-loop pivot), condensed to 10 abstracted problems + proposals. Full text in
`/private/tmp/claude-501/.../scratchpad/skygrid-handoff-batch1.txt` (session-local scratch, not
durable — the 10 items are restated below for the durable record).

1. Invite buried, never explained in onboarding.
2. Copy artificially caps circle at 1 buddy; data/rules already support N — keep pairwise edges,
   raise product-level cap (~8), don't build a shared-group model.
3. Day-1 share artifact only reachable via milestone, not an ordinary day.
4. Inviter never notified when their invite is accepted.
5. Buddy list rows show no state; only destination is block/report.
6. Onboarding's first-screen copy is stale ("color" record; product is now actual photos).
7. Single fixed alarm time; no motion-gated dismissal (note: OS silences alarm before app code
   runs, so any gate must be in-app, not on the OS alarm's own Stop button).
8. Pre-capture home card is a generic gradient — anchor in yesterday's actual photo instead.
9. Buddy-refresh read fan-out is uncapped; will scale poorly as circle size grows.
10. External design research (Apple HIG, BeReal, Erly) and Erly-specific ASO comparison not done.

### Codex's verification report (received 2026-09-04, after 6m45s)

> 検証完了です。主要仮説は概ね正しい一方、まず分母を含む計測契約が不足しています。

- Reveal + capture-completed events implemented; **D7 mutual-reveal rate still undetermined** —
  install/first-open denominator and aggregation path unverified.
- Confirmed: pairwise friendship model already safely supports multiple buddies. Explicitly
  **rejected** a shared-group model (would break existing members' consent) — agrees with our
  proposal's own reasoning.
- Refinement we didn't specify: the "max 8" cap can't be enforced by UI/copy alone — needs
  **server-side enforcement on both the handle-invite path and the link-claim path**.
- Confirmed and addressed: ordinary-day share entry point, inviter notification, buddy-row state
  display, stale onboarding "color" copy, single alarm, generic pre-capture card, unbounded Today
  read fan-out.
- Refinement: inviter notification should collapse friendship create + pending→accepted into
  **one** trigger, sent only to `requestedBy`; also needs an in-app fallback display for when the
  push itself is denied/undeliverable.
- Refinement: Today's *rendered* list stays capped at 12 (matches UI) but the *total accepted
  count* must be tracked separately — a naive `limit(12)` at the repository-query level would
  silently break pending/block management.
- **Item 10 (design/ASO research) not yet actioned** — explicitly flagged as still open.
- Added a measurement contract (hypotheses + retraction conditions) to `PRODUCT-MODEL.md:1`.
- Verified: Functions tests (59) green, Functions type-check green, iOS Simulator build green.
  **Not verified**: Firebase Analytics real event delivery/aggregation, push delivery on a real
  device.

---

## Batch 2 (sent 2026-09-04, ~12:xx JST — single item, cadence changed to one-at-a-time)

Acknowledged Codex's two refinements from batch 1 (server-side cap enforcement on both
handle-invite and link-claim paths; single collapsed friendship-notification trigger scoped to
`requestedBy`) as correct, superseding my original description.

Single item sent: the D7 mutual-reveal-rate denominator Codex flagged as unverified. Proposal:
before building new install-tracking instrumentation, check whether Firebase Analytics'
auto-collected `first_open` event already covers it (it very likely already flows into the same
Firebase project since FirebaseAnalytics is already linked) — the real gap may be the
first_open→capture_completed→reveal cohort *query*, not new client-side collection. Only propose a
new custom event if `first_open` turns out to be genuinely unusable, and scope it to the actual
gap, not a general install-tracking system.

Status: sent, Codex acknowledged and started working. Awaiting result.

## Next candidates (not yet sent — pick one per future turn, check off / annotate when sent)

- [ ] Item 10 (still open per Codex): external design research (Apple HIG, BeReal reveal/UI
      patterns, Erly onboarding+ASO) before further visual changes — this is a real research task,
      not a quick abstracted note; scope it down to one concrete sub-question at a time rather
      than resending the full "≥50 sources" ask in one turn.
- [ ] Firebase Analytics real event delivery/aggregation — Codex flagged this as unverified
      locally (no console access from their sandbox either, presumably) — may need the human's
      Firebase console access; flag back to the user rather than looping on it indefinitely.
- [ ] Push notification real-device delivery — same category, likely needs a real device + human.
- [ ] Once first_open/cohort question resolves, close the loop: ask Codex for the actual D7
      mutual-reveal-rate value once computable, to replace `unmeasured` in PRODUCT-MODEL.md.

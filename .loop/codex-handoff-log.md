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

Status: **result received (2026-09-04, after 2m46s)**. Codex's finding supersedes my proposal:
**Firebase Analytics is currently disabled in the shipped config**, not merely un-queried.
`GoogleService-Info.plist` has `IS_ANALYTICS_ENABLED = false` and no measurement ID; no BigQuery
export dataset exists either; a past Analytics property (if any) can't be confirmed — Admin API
read access is missing. So `first_open` is not flowing anywhere right now, and neither is any of
the capture/invite/reveal events already in the client. **Codex correctly did not flip this
itself** (an external Firebase Console change needs explicit human approval) — it updated
`PRODUCT-MODEL.md:9` with the corrected fact and stopped there.
**BLOCKED — needs the human**: enable Google Analytics for the Firebase project in the Firebase
Console, download the updated `GoogleService-Info.plist`, ship it in the next build. Everything
downstream of this (D7 mutual-reveal rate, and *every* funnel number this loop has been assuming
exists) is unmeasurable until that one manual step happens. Flagged to the user directly (not
something either agent loop should keep re-discovering).

## Next candidates (not yet sent — pick one per future turn, check off / annotate when sent)

- [x] ~~Firebase Analytics real event delivery/aggregation~~ — resolved into a clear blocker
      (Analytics disabled at the config level). Reported to the human 2026-09-04; not a Claude/Codex
      task until the human flips it in Firebase Console.
- [ ] Item 10 (still open per Codex): external design research (Apple HIG, BeReal reveal/UI
      patterns, Erly onboarding+ASO) before further visual changes — this is a real research task,
      not a quick abstracted note; scope it down to one concrete sub-question at a time rather
      than resending the full "≥50 sources" ask in one turn.
- [ ] Push notification real-device delivery — same category as Analytics, likely needs a real
      device + human; do not send to Codex until there's a concrete code-level question to ask.
- [ ] Once Analytics is enabled by the human, ask Codex for the actual D7 mutual-reveal-rate value
      (or confirm the cohort query is ready to run) to replace `unmeasured` in PRODUCT-MODEL.md.

## Batch 3 (sent 2026-09-04 — cadence changed to every 10 min per user)

Onboarding: add a skippable invite step at the end (reuse existing `createInvite` + share sheet);
evaluate cutting `pace`/`frequency` steps to make room, but only after confirming what
`PersonalizedPlanView` actually consumes from `PersonalizationProfile` — don't cut blind.

**Result (received 2026-09-04, 4m52s):** Implemented. Added a skippable step 9
(`Onboarding/OnboardingInviteView.swift`) explaining the mutual-reveal mechanic, letting the user
create a handle if needed then reuses the existing invite-link + share-sheet flow unchanged;
resumed onboarding with an existing handle skips straight to the invite link. Kept `pace`/
`frequency` — verified they feed `PersonalizedPlanView` and paywall copy, so not decorative.
Tagged the invite event `placement: onboarding` (lets us compare conversion against the existing
Buddies-tab invite placement later). Added an onboarding-transition test; iOS Simulator build and
that test both green. Files: `OnboardingInviteView.swift`, `OnboardingCoordinatorView.swift:4`,
hypothesis + retraction condition recorded in `PRODUCT-MODEL.md:46`.

**Noted in passing (not yet actioned, low priority):** a Swift 6 language-mode warning in
`Data/Firebase/FirebaseInviteRepository.swift:17` (`main actor-isolated static property 'region'
can not be referenced from a nonisolated context` — will become a hard error under strict Swift 6
concurrency checking). Candidate for a future turn once the higher-priority items are through.

## Batch 4 (sent 2026-09-04 — cadence now every 5 min per user)

Correction, not a new feature request: the user reports enabling Google Analytics in the Firebase
Console and downloading a fresh `GoogleService-Info.plist`
(`~/Downloads/GoogleService-Info (2).plist`, downloaded 2026-09-04 12:43). **I independently
checked it with PlistBuddy before sending this and it still reads `IS_ANALYTICS_ENABLED = false`
with no measurement ID** — identical to the two older downloads in the same folder (Jul 1, Jul
29). So the Console change likely didn't fully take (project-level "enable Analytics" is a
different step from linking Analytics to this specific iOS app registration). Also worth being
explicit with Codex: **Firebase Analytics SDK is already integrated and already in active use**
(`PaywallAnalytics.swift`, `InviteAnalytics.swift` already call `Analytics.logEvent`) — there is no
SDK-addition or initialization code to write; the only gap has only ever been the Console-side app
registration + BigQuery export. Sent Codex the file path and asked it to independently verify
before touching anything, and to only replace the in-repo plist if the new file genuinely shows
Analytics enabled — otherwise report back exactly what's still missing so it can be relayed to the
user precisely (which Console screen/step to check).

**Result (received 2026-09-04):** Independently re-confirmed disabled (own PlistBuddy-equivalent
check, not just trusting mine). Bundle ID and Firebase project ID are correct for SkyGrid — ruled
out "wrong app's plist downloaded." Root cause is that **the Firebase project itself was never
connected to a Google Analytics property** (a separate step from anything per-app). Did not copy
the file into the repo (correct call, still invalid). Confirmed no SDK/init code is needed — once
the project↔Analytics link exists, the existing Firebase app auto-links to a data stream. Recorded
the exact procedure + verification result in `PRODUCT-MODEL.md:67`.

**Precise steps for the human (relayed 2026-09-04):**
1. Firebase Console → Project settings → **Integrations**.
2. Select **Google Analytics** → connect an existing or new Google Analytics account/property →
   complete the terms-of-service acceptance.
3. Only after that: Project settings → General → Your apps → iOS app `com.takmin.skygrid` → **re-download** `GoogleService-Info.plist`.
4. Before replacing the file in the repo, confirm it now shows `IS_ANALYTICS_ENABLED=true` and a
   real measurement ID. (Step 1-2 is the part that's actually missing — steps 3-4 are what was
   already tried, correctly, just too early.)

Not something either agent can do further on right now — waiting on the human's Firebase Console
action.

## Batch 5 (sent 2026-09-04 — 5 min cadence continues)

Small technical-debt item you noted in passing during batch 3: the Swift 6 language-mode warning
in `Data/Firebase/FirebaseInviteRepository.swift:17` (`main actor-isolated static property
'region' can not be referenced from a nonisolated context`) — flagged as becoming a hard build
error under strict Swift 6 concurrency checking. Asked you to fix it now while other items are
blocked on the human, plus do a quick repo-wide grep for the same pattern elsewhere so this isn't
a one-off fix that leaves siblings broken.

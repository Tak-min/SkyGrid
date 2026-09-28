# VISION — buddy vertical feed + quiz-funnel onboarding expansion

> Anchor file for `.loop/buddy-feed-and-onboarding_2026-09-28/`. Independent from
> `.loop/uiux-autonomy_2026-09-25/` (that loop's Round 4 closed; this is new feature/content work,
> not bug-fix polish — do not merge scopes). Base commit: `679e5b146ef59a61cbb4365643370abe5b052d4b`.

## Goal

Two owner-directed product changes, explicitly separated from the bug-fix loop:

**Track A — Buddy feed, vertical.** Today `BuddyRow.swift` is a horizontal scrolling strip of
buddy tiles. Owner wants a BeReal-style vertical scrolling feed instead. Per design direction
(senior-designer pass, 2026-09-28): ship this as a **pure UI relayout of the existing 1:1 buddy
pairs first** — no Firestore/data-model change, no N-way-group migration (that stays a distinct
future initiative per the stale root `.loop/VISION.md`'s own decision record — do not attempt it
here). The mutual-reveal gate logic (`BuddyTile`'s `revealState`) is unchanged; only the layout
container changes from horizontal `ScrollView`+`HStack` to a vertical `LazyVStack` feed of
wider/taller cards.

**Track B — Onboarding expansion to a quiz-funnel structure.** Owner's explicit correction
(2026-09-28) to an earlier "shorten onboarding" proposal: **longer is intentional**. Real
precedent: health/habit subscription apps (the category SkyGrid competes in) commonly run
~20-25 screen onboarding funnels that interleave personalization questions with short
educational content, and defer the paywall until real value/education has been delivered —
the users who complete a long funnel skew toward higher purchase intent. Direction:
- Keep and slightly grow the existing personalization questions (currently 6:
  `intention, pace, frequency, privacy, reminder, wakeGoal` in `OnboardingStep`).
- Each question's answer must visibly change something immediately after — a personalized
  reflection line ("あなたのペースだと...") AND a real downstream effect (e.g. `pace`/`reminder`
  feed `MorningAlarmScheduler`'s initial defaults, `privacy` feeds the buddy-invite default
  posture) — currently these answers are captured into `PersonalizationProfile` but nothing reads
  them downstream (confirmed by grep, zero call sites outside Onboarding). That's a real defect,
  fix it as part of this work, not just add more screens.
- Interleave short educational slides between questions: general, non-medical, widely-accepted
  framing only (circadian rhythm basics, morning light exposure and alertness) — do not phrase
  anything as a medical/health claim or cite a specific study; keep it to the same tone level as
  a consumer wellness app's marketing copy, not a clinical claim. Never invent a statistic.
- Include at least one **functional demo moment** (not just narration) before the paywall,
  matching the existing BeReal/Erly research already in `dev-notes/design-research-sources_2026-
  09-04.md` (source #12): land the user in a real, simplified version of an actual screen rather
  than describing it.

## Recon already done (2026-09-28 — don't re-derive)

- **Buddy feed**: `ios/SkyGrid/Sources/Today/BuddyRow.swift` (50 lines) — horizontal
  `ScrollView`+`HStack` of `BuddyTile`. Reveal-gate logic lives in `BuddyTile` itself (untouched
  by this work). `TodayViewModel.BuddyStatus` is the data source — same source, just re-laid-out.
- **Onboarding flow**: `OnboardingStep` enum in `OnboardingCoordinatorView.swift` (345 lines) is
  a linear state machine: `language → welcome → intention → pace → frequency → privacy →
  reminder → wakeGoal → plan → invite`. `advance()`/`goBack()` switch statements drive
  forward/back navigation — new steps insert as new enum cases + new switch arms (both
  directions, don't forget `goBack`). `PersonalizationQuestionsView.swift` (263 lines) holds the
  `SingleQuestionPage` shared layout used by `PaceQuestionView`/`FrequencyQuestionView`/
  `PrivacyQuestionView`/`ReminderQuestionView` — reuse this component for new question screens.
  `PersonalizationProfile.swift` holds the answer model — currently write-only, never read
  downstream (grep confirmed zero call sites outside `Onboarding/`).
- **Design conventions**: `DESIGN.md`'s ENERGY 4/5, RHYTHM 4/5, MOTION 4/5 dials apply (this is
  the celebratory/expressive register, not the calm ENERGY-1 ExportTheme register). Read before
  building any new screen.
- **Content constraint**: no unverifiable health claims, no invented statistics, no medical
  framing — see Track B goal above. If a fact is stated, it must be genuinely uncontroversial
  consumer-wellness-copy level (e.g. "morning light helps your body clock" is fine; a specific
  percentage or named study is not, unless independently verified against a real source).

## Required roles per ticket (same role-separation convention as uiux-autonomy)

Each ticket goes through: pick from TODO → implement (dispatch to Codex per
`~/.claude/rules/ecc/common/codex-delegation.md`) → independent review (`swift-reviewer`) →
antislop-ui Delivery Gate (both tracks are heavily user-visible) → verify → commit. Skip the
separate discovery/metric/eval sub-dispatches used by the bug-fix loop — direction here is
already owner-specified, not something to re-discover.

**Model routing**: once the first education-slide screen and the first personalized-reflection
component exist as a reusable pattern (Ticket 1/2 below), later screens that just plug new copy
into that established pattern are fully-specified, zero-ambiguity packets — dispatch those to
Codex with `model: "gpt-5.6-luna"`, in parallel when several are ready at once (owner explicitly
authorized parallel Codex dispatch again, 2026-09-28). The `OnboardingStep` enum/state-machine
edits and the `BuddyRow` reveal-gate-preserving relayout are judgment calls — leave `model`
unset so Codex self-routes Terra/Sol.

## Definition of Done — Phase 1 (bounded first checkpoint, not the full 25 screens)

- [ ] Track A: `BuddyRow` relaid out as a vertical scrolling feed; `BuddyTile`'s reveal-gate
      logic unchanged and re-verified still correct in the new layout (both revealed and
      not-yet-revealed states, screenshot-checked via the UI-audit harness).
- [ ] Track B, Ticket 1: build the reusable "education slide" component (image/illustration +
      short non-medical copy + Continue) as a new `OnboardingStep` case, styled per DESIGN.md's
      ENERGY 4/5 register.
- [ ] Track B, Ticket 2: `PersonalizationProfile`'s answers actually drive something downstream —
      at minimum `pace`/`reminder` seed `MorningAlarmScheduler`'s initial default, `privacy`
      seeds the buddy-invite default posture — plus an immediate on-screen personalized
      reflection line after each question, using the real stored answer (not a placeholder).
- [ ] Track B, Ticket 3: insert at least 3 education slides at meaningful points in the flow
      (after `intention`, after `pace`/`frequency`, before `plan`) using Ticket 1's component,
      and at least one functional demo moment before `plan` (e.g. a simplified real camera-review
      screen touch, not narration).
- [ ] Track B: onboarding step count grows from 10 to at least 16 (measurable via the
      `OnboardingStep` enum's case count) — a real step toward the ~25-screen target, not the
      final number; Phase 2 continues from here.
- [ ] `bash .loop/buddy-feed-and-onboarding_2026-09-28/verify.sh` exits 0.
- [ ] No CRITICAL/HIGH reviewer findings remain unaddressed.

## Constraints / guardrails (inherited, do not weaken)

- Never `git add -A` — explicit paths only, every commit.
- Never `firebase deploy`, `git push`, or any App Store Connect action — 1.0.11 is already
  `WAITING_FOR_REVIEW`; this loop's work targets a FUTURE version, not that one.
- Do not touch `ios/functions`, `ios/firestore.rules`, `ios/SkyGrid.xcodeproj/project.pbxproj`
  (hand-edited) — Track A/B are both pure-client, no backend schema change.
- Do not attempt the N-way buddy-group data-model migration — that's explicitly out of scope
  here (see Track A above).
- No invented health/medical claims or statistics (see Track B content constraint above).
- Read every Codex-changed file directly before trusting its summary.

## Progress log

- 2026-09-28: Loop scaffolded by the owner's interactive session after a senior-designer pass
  and an explicit owner correction on onboarding length/style. Base commit `679e5b1`.

## TODO

- [ ] Ticket A1: relayout `BuddyRow` from horizontal to vertical scrolling feed (see Definition
      of Done above for acceptance).
- [ ] Ticket B1: build the reusable education-slide `OnboardingStep`/component.
- [ ] Ticket B2: wire `PersonalizationProfile` answers to real downstream effects + immediate
      personalized reflection copy.
- [ ] Ticket B3: insert 3+ education slides and 1+ functional demo moment using B1's component,
      growing the step count from 10 to 16+.
- [ ] (Further tickets toward the full ~25-screen target are Phase 2 — append here once Phase 1
      closes.)

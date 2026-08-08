# Sky Grid — UI/UX audit (2026-08-08)

Method: built `Debug` for iPhone 17 Pro (iOS 26.5) and drove the app's own
`-SkyGridUIAudit -SkyGridUIAuditScenario <name>` harness (`SkyGridApp.swift:33`), capturing
`today`, `grid`, `buddies`, `paywall`, `onboarding`, `camera-review`, `settings`. Findings
below are from those screenshots plus source verification — each names file:line.

Screenshots: `/private/tmp/.../scratchpad/shots/*.png` (session-local).

---

## A. Dead / unwired core mechanics (the biggest finding)

These are not styling problems. Three of the product's headline mechanics are **implemented,
tested, and never reachable by a user.**

### A1 — CRITICAL — The streak is never computed or displayed anywhere
- `Streak/StreakCalculator.swift` is fully implemented and unit-tested
  (`Tests/StreakCalculatorTests.swift`), but `grep` finds **zero production call sites**. The
  only references are its own doc comments.
- `UserProfile.streakCurrent` / `.streakLongest` (`Models/UserProfile.swift:12-13`) are
  decoded (`FirebaseDocumentCodec.swift:52-53`) and initialised to `0`
  (`FirebaseUserRepository.swift:50-51`) — and **never written and never read by any view.**
- Net effect: a daily-streak app in which the streak does not exist in the UI. `TodayView`
  shows only "2 / 7" for the current week (`TodayView.swift:237`).
- This is simultaneously the #1 UX gap and the #1 viral gap: the streak number is the single
  most screenshot-able, most flex-able object the product could own.

### A2 — CRITICAL — The buddy reveal never appears on the home screen
- `TodayViewModel` does the full buddy fan-out every session — observes friendships, fetches
  each buddy's profile and today's post, and publishes `buddies: [BuddyStatus]`
  (`TodayViewModel.swift:24, 194-212`).
- `TodayView` never reads `viewModel.buddies`. The result is computed and discarded.
- `Today/BuddyRow.swift` and `Today/BuddyTile.swift` — which render exactly that data with
  the mutual-reveal blur — are **dead code**: `BuddyRow` has no call site, `BuddyTile` is only
  used by `BuddyRow`.
- `Friends/BuddyRevealGate.swift`, the "your sky unlocks theirs" rule that the Buddies tab
  advertises in its header ("Two skies, revealed together"), is therefore unreachable.
- Consequences: (a) the app's whole social hook is invisible where it matters; (b) the
  Firestore reads for buddies are paid on every Today session for nothing.

### A3 — HIGH — No milestone / celebration moment exists
- `AppReviewPromptPolicy` and `AutomaticPaywallPresentationPolicy` both key off
  `completedCaptureCount`, so milestone counts are already tracked
  (`LocalDefaults.completedCaptureCount`). Nothing celebrates them in-app.
- There is no shareable moment at any point except the manual year-export button.

---

## B. Concrete visual defects

### B1 — HIGH — The year grid, the product's signature artifact, is illegible
- `SkyGridView.gridField` (`SkyGridView.swift:147-157`) fits a 31×12 `GridCanvas` to the
  screen width via `.aspectRatio(31/12, contentMode: .fit)`. On a 393pt-wide device that
  leaves ≈10pt per cell, and the mosaic reads as a flat grey band with a thin coloured stripe
  rather than a year of skies (see `shots/grid.png`).
- Empty cells all render as the same `SGT.ghost` fill (`GridCanvas.swift:32`) with
  `spacing: 0`, so there is no month/week structure to read against — and the trailing
  out-of-month cells produce hard white rectangles at the right edge that look like a
  rendering glitch.
- The screen directly below it (`MonthlyPhotoGrid`) is legible and attractive — the contrast
  makes the hero element look broken.

### B2 — HIGH — Startup failure leaks a raw internal error to the user
- `AppStartupView.swift:41` renders `Text(error.localizedDescription)` verbatim. With the
  current App Check failure this shows, on the very first screen:
  `"Sky Grid could not connect. Check your connection and try again. The operation couldn't
  be completed. (SkyGrid.RepositoryError error 1.)"`
- `RepositoryError` (`Data/RepositoryError.swift`) has no `LocalizedError` conformance, so
  every case falls back to Foundation's default enum description.

### B3 — MEDIUM — The empty-morning time placeholder reads as a broken glyph
- `TodayView.swift:186-188` renders `"—:—"` at `SGFont.bigTime(74)` (ultraLight, monospaced
  digits). Two em-dashes and a colon at 74pt ultraLight render as detached hairlines and
  floating dots (see `shots/today.png`) — it looks like a font-loading failure, not an
  "unrecorded" state.

### B4 — MEDIUM — Archive notice is clipped by the floating tab bar
- `SkyGridView.swift:42-52` places the "Free keeps your most recent 30 days visible." notice
  and its "Unlock the full archive" button last, inside `.padding(.bottom, 128)`
  (`SkyGridView.swift:59`). At default Dynamic Type the notice is already half-hidden behind
  the tab bar (`shots/grid.png`), and its upgrade button is not reachable without a
  deliberate over-scroll.

### B5 — MEDIUM — Buddy list rows carry no information
- `BuddiesView` renders buddies as bare name rows with a chevron ("Mira", "Ren" —
  `shots/buddies.png`). No sky colour, no streak, no "posted today" state, no avatar — even
  though `BuddyStatus` already carries `hasPostedToday` and `post.skyColor`.

### B6 — LOW — Disabled "Send request" button has weak contrast
- The disabled state renders mid-grey on the warm card fill (`shots/buddies.png`), reading as
  an already-tapped/broken control rather than "fill in a handle first".

---

## C. Persona findings (against the "viral" brief)

The current persona is deliberately, explicitly quiet, and the code says so:

- `TodayView.swift:3` — "the first five seconds never resemble a social feed or a dashboard"
- `Theme.swift:8` — "The app itself has no fixed brand color"
- `ViewModifiers.swift:3` — the single shared surface is literally named `quietCard()`
- Onboarding copy: *"Its color becomes one **quiet** day in your grid."*
  (`shots/onboarding.png`)

Consequences for shareability:

### C1 — HIGH — The share card will not survive a social feed
- `SkyGridExportView.swift` renders 1080×1920 on `SGT.background` (`#FAF7F2` warm white) with
  `SGT.ink3` grey labels and a serif year. In an Instagram/TikTok Story it is a pale cream
  rectangle with a thin grey band — near-zero stopping power, and no number large enough to
  read at thumbnail size.
- It carries no streak, no name/handle, and no "beat me" hook. (It *does* now carry a QR +
  App Store URL from the concurrent session — keep that.)

### C2 — HIGH — There is no shareable object other than the year card
- The only `ShareLink` path is the full-year export, which is only meaningful after months of
  use. A day-one user has nothing to post — so the viral loop cannot start until a user is
  already retained, which is backwards.

### C3 — MEDIUM — Onboarding sells calm, not the hook
- 8 steps (`01 / 08`), serif, pale, and the pitch is "one quiet day in your grid". Nothing
  states the social mechanic (mutual reveal) or the streak, which are the two reasons a person
  would tell a friend.

---

## Priority for this loop

1. A1 + A2 — wire the streak and the buddy reveal into Today (fixes dead code, the UX hole,
   and supplies the objects the viral surface needs).
2. C1 — rebuild the share artifact so it reads at thumbnail size and carries the streak.
3. B1, B2 — the two most visible defects.
4. A3 + C2 — a milestone moment that produces a day-one shareable card.
5. B3, B4, B5, B6 — polish.

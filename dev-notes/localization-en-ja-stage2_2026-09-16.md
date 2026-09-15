# Sky Grid localization stage 2 — 2026-09-16

## Scope and who did this

`dev-notes/localization-en-ja-brief_2026-09-12.md` originally specified that ChatGPT-web would
implement both stages and Claude Code would only verify. Stage 1 (the mechanism) was implemented
that way and verified/committed by Claude Code on 2026-09-15 (`9830b29`).

**Stage 2 (this document) was implemented directly by Claude Code**, per the owner's explicit
instruction in this session to complete the full translation autonomously. This supersedes the
brief's original "Claude Code does not implement" constraint for stage 2 only; `PRODUCT-MODEL.md`
§5 item 6 has been updated to record this.

## What stage 2 covers

1. Full in-app UI translation: every `Text`/`Label`/`Button`/`.accessibilityLabel`/
   `.accessibilityHint`/`.navigationTitle`/`.alert` literal, all Moku ambient messages, all
   streak-milestone copy, all onboarding personalization question/answer copy, all Settings rows,
   all paywall copy, all invite-flow terminal states, and all `LocalizedError` descriptions
   reachable from the UI (`RepositoryError`, `AppStartupError`, `AppleAccountLinkError`,
   `RevenueCatConfigurationError`).
2. `InfoPlist.xcstrings`: `NSCameraUsageDescription` and `NSAlarmKitUsageDescription` (polite
   register, since App Review reads these).
3. Server-side per-device language for push notifications (`buddyNotifications.ts`,
   `inviteNotifications.ts`, `buddyNotificationStore.ts`, `inviteNotificationStore.ts`):
   devices are grouped by their recorded `language` and each group gets its own
   `sendEachForMulticast` call with language-specific copy. `firestore.rules` now permits an
   optional `language` field on `users/{uid}/devices/{tokenId}`, restricted to `'en'`/`'ja'`.
   `FirebaseDeviceRegistrar` persists the selected language alongside the FCM token and
   re-persists it immediately on an in-app language change (new `.skyGridLanguageDidChange`
   notification posted from `LocalizationController.select(_:)`), so a mid-session switch reaches
   server notifications without waiting for the next token refresh.
4. App Store metadata drafts: `metadata/app-info/ja-JP.json`,
   `metadata/version/1.0.5/ja-JP.json`. App Store Connect registration remains the owner's own
   task per the brief.

## The real difficulty: stage 1's key-matching assumption did not hold everywhere

Stage 1's mechanism (Bundle-swizzle + String Catalog) correctly localizes a **literal** string
passed directly to `Text("...")`, `Label("...")`, etc. — SwiftUI treats that literal as a
`LocalizedStringKey` and looks it up in the catalog using the literal text itself as the key.

But a large fraction of this app's copy is **not** a literal at the `Text(...)` call site. Three
recurring patterns silently bypass String Catalog matching entirely, because Swift resolves
`Text(_:)` to its *verbatim* `StringProtocol` overload (no catalog lookup at all) whenever the
argument's static type is `String` rather than a literal expression:

- **Stored/computed `String` properties**: `Text(milestone.title)`, `Text(statusText)`,
  `Text(companionLine)`, an `errorDescription: String?` on a `LocalizedError` — anything where
  the string was built by ordinary Swift code (a `switch`, a ternary, string interpolation)
  before reaching `Text`.
- **Named `String` parameters on custom helpers**: `sectionLabel("THIS WEEK")`,
  `settingRow("Delete account", ...)`, `yearButton(label: "Show previous year", ...)`,
  `terminal(title: "This link has expired", ...)` — the literal is textually present at the call
  site, so an `rg 'Text\(\s*"'`-style scan (the brief's own verification command, and this
  agent's first-pass inventory) never finds it, yet the string never reaches a `Text(literal)`
  form.
- **`Text(condition ? "a" : "b")`**: still a `String`-typed *expression*, not a literal, even
  though both branches are literals.

**Fix applied throughout**: every such case now resolves through `L10n.string(_:)` (stage 1's own
explicit-key lookup path), either directly or via `String(format:)` for interpolated content. Each
site is commented `// Routed through L10n.string(_:) ... does not apply here` pointing back to
this file, so a future contributor adding a new `Text(someString)` call has the pattern documented
in-repo, not only here.

One additional correctness bug found and fixed in the same sweep: `MokuAmbientMessage.swift`'s
five message-pool arrays were originally `private static let` — Swift lazily evaluates a
`static let` exactly once and caches it for the process lifetime, so the *first* language a
category's array was read in would have been permanent regardless of later language switches.
Changed to `private static var` (computed on every access) to keep them live.

### How the gap was actually found

Static grep coverage plateaued after the first inventory pass. What actually surfaced the
remaining gaps was running the app in the iPhone 17 simulator — whose **system language is
Japanese** (`ja-JP`) — and reading the live screen: `THIS WEEK` (Today) and the entire Settings
screen (which goes through `settingRow`/`settingsSection` helpers) were still rendering in raw
English text even with the catalog fully wired, which is what led to grepping for the
named-parameter and ternary patterns above. This is also what caught six `PersonalizedMorningPlan`
test assertions that had baked in an English-only assumption (see below) — they only failed
because the simulator's locale is genuinely Japanese, not fabricated for the test.

**Coverage is now verified two ways, not one**: (1) every `Text`/`Label`/`Button`/
`.accessibilityLabel`/`.accessibilityHint`/`.navigationTitle`/`.alert` literal call site has a
catalog entry; (2) every `L10n.string("key")` reference in the source has a matching catalog key.
Both checks currently return zero gaps (see verification commands below). This is a much stronger
guarantee than stage 1's original single-direction scan, but it is still a static, source-level
check — see "Known limitations" for what it does not cover.

## Tests fixed (locale-dependent assertions, not implementation bugs)

`PersonalizationProfileTests.swift`'s two tests for `PersonalizedMorningPlanBuilder` asserted
hardcoded English substrings (`.contains("year of skies")`, `.contains("30 days")`, etc.). Once
`PersonalizedMorningPlanBuilder` correctly localizes through `L10n.string(_:)`, those assertions
are language-dependent and failed under the Japanese-locale simulator. Per the stage-1 brief's own
rule ("don't rewrite a test just to make it pass, but do rewrite one whose assumption a real spec
change invalidated, and record why"): rewrote both tests to compare against the same
`L10n.string(_:)`-resolved catalog values the implementation reads, rather than English literals —
this keeps the tests' actual intent (the correct branch is chosen for each profile answer)
language-independent. `StreakMilestoneTests` already anticipated this exact class of problem
(it only checks non-emptiness/uniqueness, never exact copy) and needed no change.

## Verification performed

1. `cd ios && xcodegen generate` — `ja` present in `knownRegions`; `InfoPlist.xcstrings` required
   a *second* `xcodegen generate` after being added, since it didn't exist at the first run.
2. `xcodebuild build` — succeeds, no missing-localization warnings.
3. `xcodebuild test -only-testing:SkyGridTests` — **336/336 pass** (both before and after the
   `PersonalizationProfileTests` rewrite; other files never asserted exact copy).
4. Mixed-language scan (brief's own command) — 0 Japanese literals in `.swift` sources; all
   Japanese lives in `Localizable.xcstrings`/`InfoPlist.xcstrings`.
5. Catalog cross-check (this stage's addition) — 0 literal `Text`/... calls without a catalog
   entry; 0 `L10n.string("key")` references without a catalog entry. 583 total catalog keys.
6. Compiled-bundle inspection — built `.app`'s `ja.lproj/Localizable.strings` and
   `ja.lproj/InfoPlist.strings` contain every key with the authored Japanese value (spot-checked
   programmatically, not just by trusting the source `.xcstrings`).
7. Live simulator check (iPhone 17, system language `ja-JP`) — fresh launch renders Today,
   including Moku's ambient message and the onboarding-adjacent copy, entirely in Japanese;
   screenshots taken before and after the `THIS WEEK`/Settings fix confirm the specific regression
   found and its resolution.
8. `cd ios/functions && npm run test` — **83/83 pass** (80 pre-existing + 3 new: Japanese
   `buddyPostNotificationCopy`, `deviceLanguageFromDoc`, Japanese `inviteClaimedNotificationCopy`).
9. `firebase emulators:exec --only firestore,storage` for `rules-tests` — **could not run in this
   environment**: `java -version` fails (`Unable to locate a Java Runtime`) on this machine, which
   blocks the Firestore/Storage emulator regardless of any change here. The `firestore.rules` diff
   and the new `rules-tests/test.js` device-registration `describe` block were written and
   reviewed but are **unverified by execution** — run `cd ios && firebase emulators:exec --only
   firestore,storage "cd rules-tests && npx mocha test.js --timeout 20000"` once Java is
   available.

## Known limitations (deliberately out of scope, or genuinely unresolved)

- **Widget / Live Activity**: unchanged from stage 1 — still follows device language, not the
  in-app selection. Stage 1's own §1.5 deferral stands; no App Group work was done here.
- **`Calendar.current.veryShortWeekdaySymbols`** (`MorningAlarmSettingsView.weekdayButton`): the
  single-letter weekday abbreviations follow the *device* locale, not the in-app selected
  language, since `Calendar.current` isn't overridden by this app's Bundle-swizzle mechanism (only
  string-table lookups are). Low-visibility (single letters on the custom-schedule weekday
  picker); not fixed.
- **`.formatted(date:time:)` calls that aren't explicitly locale-pinned** (e.g.
  `BuddiesView`'s "Connected \(date)"): these use `Locale.autoupdatingCurrent` (device locale) for
  the *date formatting itself*, while the surrounding sentence template is correctly
  language-aware. A device set to English with the in-app language set to Japanese would show a
  Japanese sentence around an English-formatted date. `TodayView.todayHeading` was fixed to use
  the in-app language explicitly (see diff) because it's a prominent, always-visible heading;
  other, lower-visibility instances were not audited exhaustively.
- **Third-party SDK error text** (`error.localizedDescription` from Firebase/Apple SDKs, used as a
  fallback in a few error paths) is inherently English and out of scope — wrapping every possible
  SDK error is not reasonable.
- **App Store Connect registration** of the `ja-JP` metadata drafts is the owner's own task per
  the brief (unchanged from stage 1's division of responsibility).
- The exhaustive `Text(variable)` / named-parameter / ternary sweep was done by hand across the
  whole `SkyGrid/Sources` tree and cross-verified against every `L10n.string` reference, but it is
  still a manual, non-exhaustive-by-construction process (unlike the two automated checks in
  "Verification performed" §5, which are complete by construction). If a future PR adds a new
  `Text(someComputedString)` call, nothing currently catches it automatically — see the in-code
  comments left at each fixed site for the pattern to watch for.

## Files changed

Very broad by necessity (a real i18n pass touches most UI files) — see `git diff --stat` /
`git log` for the exact list rather than duplicating it here. The shape: `Localizable.xcstrings`
(583 keys) and `InfoPlist.xcstrings` (2 keys) carry all copy; Swift changes are almost entirely
either (a) no change (literal already catalog-matched) or (b) routing a stored/computed string
through `L10n.string(_:)`/`String(format:)` instead of a raw literal. Server-side changes are
scoped to the four notification-related `.ts` files, `firestore.rules`, and `rules-tests/test.js`.

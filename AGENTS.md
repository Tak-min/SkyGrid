# Sky Grid — project AGENTS.md

updated: 2026-08-11

An iOS wake-up app, live on the App Store since 2026-08-06 (1.0.1 `READY_FOR_SALE`).
Every morning you photograph the sky; each capture becomes one cell in a year-long
mosaic. A buddy's sky stays blurred until both people have posted that day.

## Scope and architecture

- Scope: `ios/` (SwiftUI app + Cloud Functions + Firestore/Storage rules),
  `waitlist/` (the `skygrid.my` Cloudflare Worker site), `dev-notes/` (the written record).
- Runtime entry points: `ios/SkyGrid/Sources/App/SkyGridApp.swift`,
  `ios/functions/src/index.ts` (all callables and the RevenueCat webhook).
- Backend authority: **Firestore Security Rules are the only written schema** for
  `friendships`, `handles`, `users`, `posts`. Server code that writes those collections
  must satisfy them even though the Admin SDK bypasses them — see "Change rules".
- Protected contracts: `friendships/{pairId}` document shape, `invites/{code}` document
  shape, the four invite callables' request/response shapes, RevenueCat product IDs.
- Purchases go through **RevenueCat**, not StoreKit directly.

## Repository commands

Run from the stated directory. There is no root-level task runner.

- Functions install: `cd ios/functions && npm install`
- Functions typecheck: `cd ios/functions && npm run lint` (`tsc --noEmit`)
- Functions tests (no Firebase needed): `cd ios/functions && npm test`
- Functions emulator tests: `cd ios/functions && npm run test:emulator`
- Rules tests: `cd ios/rules-tests && npm run test:emulator`
- iOS build: `cd ios && xcodebuild -project SkyGrid.xcodeproj -scheme SkyGrid -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- iOS tests: same as above with `test` instead of `build`; add
  `-only-testing:SkyGridTests/<Suite>` to focus.
- Regenerate the Xcode project: `cd ios && xcodegen generate`

**Both emulator commands need Java, and `java` is not on PATH.** openjdk is installed
via Homebrew but is keg-only, so `/Library/Java/JavaVirtualMachines/` is empty and it
looks absent. Do not install anything — export it:

```bash
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
```

## Change rules

- **`ios/SkyGrid.xcodeproj` is generated.** The source of truth is `ios/project.yml`.
  Editing `project.pbxproj` directly is reverted by the next `xcodegen generate` — this
  has already silently reverted a version bump once. New `.swift` files and new imagesets
  under `SkyGrid/Sources` and `SkyGrid/Resources` are picked up recursively, so adding a
  file needs no `project.yml` edit, only a regenerate.
- **Server writes to `friendships` must satisfy every Security Rules constraint**, with
  the two documented exceptions in `ios/functions/src/inviteStore.ts`. `activeBuddy()` in
  `firestore.rules` calls `relationship.data.blockedBy.size()`; a document written without
  `blockedBy` makes that expression error, and a rules error denies the read — silently
  breaking buddy reads for the *other* member, in code the change never touched.
- **Never log a whole invite code.** Document IDs are the secrets. Use `codeForLog()`.
- **Avoid compound Firestore queries** unless you also add the composite index. A missing
  index is invisible in the emulator and fails 100% of the time in production.
- `ios/firestore.indexes.json` is the source of truth for composite indexes and TTL.
  The invite `createInvite` query depends on its `invites` composite index; deploy
  `firestore:indexes` and wait for ACTIVE before deploying the invite callables.
- **Deploy order is functions → rules → client**, per
  `dev-notes/backend-deploy-sequencing_2026-08-08.md`. A deployed function must be
  harmless to the already-shipped App Store client. Data/index prerequisites for a
  function are an explicit pre-step; never infer that an emulator created them.
- **Export/share-card colours must be non-adaptive literals.** `ImageRenderer` resolves
  trait-adaptive colours against an unpinned trait environment, so an adaptive token makes
  the exported image depend on the exporting device's appearance. See
  `ios/SkyGrid/Sources/DesignSystem/ExportTheme.swift`, which also documents a filename
  allowlist for who may reference `SGExport`.
- **Deploying, pushing, and App Store Connect submissions require explicit user approval.**
  Committing locally does not.

## Mechanical enforcement

| Invariant | Enforcing check |
|---|---|
| Invite claim decisions, code shape, expiry | `ios/functions/test/invites.test.js` |
| `previewInvite` and `claimInvite` never contradict each other | the agreement property test in the same file |
| Rate-limit window arithmetic | `ios/functions/test/rateLimit.test.js` |
| Friendship written by the server matches the rules' key set; concurrency | `ios/functions/test/emulator/inviteStore.test.js` |
| `invites` / `inviteRateLimits` unreachable from any client | `ios/rules-tests/test.js` |
| Buddy/post read permissions | `ios/rules-tests/test.js` |
| Share-card packing at 1 / 20 / 365 captures | `ios/SkyGrid/Tests/ContactSheetLayoutTests.swift` |
| Streaks, milestones, paywall timing, upload queue | `ios/SkyGrid/Tests/` |

## Known environment quirks

- **SourceKit diagnostics immediately after an edit are unreliable here** — `No such
  module 'UIKit'` and `Cannot find 'X' in scope` appear routinely and are false. Judge
  only by an actual `xcodebuild` result.
- Simulators available: iPhone 17 / 17 Pro / 17 Pro Max / 17e / Air. **There is no
  iPhone 16.**
- App Check blocks callables in the simulator (`exchangeDebugToken` 403), so callable
  end-to-end verification needs a real device. Simulator failures there are not logic bugs.
- The UI audit harness renders any screen without navigating to it:
  `-SkyGridUIAudit -SkyGridUIAuditScenario <name>` as launch arguments. Scenario names are
  in the `UIAuditScenario` enum in `App/SkyGridApp.swift` (`share-year`, `share-morning`,
  `paywall`, `milestone`, …). Its thumbnails are synthetic gradients, not photographs.
- **Another agent session may be working in this repo concurrently.** Files appearing in
  `git status` that you did not touch are normal here; check `ps aux | grep claude` before
  assuming they are stale. Scope every commit to files you actually changed, and never
  delete another session's dev-note.

## Completion gate

Run the focused check first, then the affected suite in proportion to risk. Record any
command you could not run and why. Review `git diff` for unrelated changes before
reporting completion — this repo genuinely does accumulate another session's edits.

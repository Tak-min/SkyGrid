# VISION — Replace averaged-color display with actual photos across SkyGrid's UI

> Anchor file for the loop-engineer skill. The loop reads this every iteration so it never
> re-derives intent from scratch. Keep it current; append recon findings here.

## Goal

SkyGrid has, since its inception, deliberately shown only the **average color** of each
morning's sky photo — never the photo itself — across every screen (buddy tiles, the 7-day
week rhythm, the 365-cell year grid, share cards). This was a repeatedly-reconfirmed design
pillar (see `VISION.md` §6 at the repo root: "主役は写真ではなく数字" / "the star isn't the
photo, it's the numbers").

**The product owner has now explicitly and deliberately reversed this decision** after
real-device testing (2026-08-14 session), and confirmed it is not a misunderstanding — it is
a considered pivot. Confirmed scope: **every screen**, not just buddy/streak. The app name
"Sky Grid" stays as-is (reinterpreted as a grid of photos, not colors). Privacy implications
(buddies can now see each other's actual photos, not just a color) were raised and explicitly
accepted by the owner ("current user count is small, so it's fine").

**Do not re-litigate this decision.** It is confirmed. Your job is to execute it thoroughly
and correctly, not to re-raise the privacy/design-history concerns already resolved above.

## Definition of Done (STOP CONDITION — must be verifiable)

The loop terminates successfully ONLY when ALL of these are objectively true:

- [ ] Every screen identified in "Known color-display sites" below (plus any others found
      during recon) renders the actual sky photo instead of (or, where a photo genuinely
      cannot be shown — e.g. a locked/sealed buddy state — in addition to) the averaged
      `SkyColor`. A locked/sealed state (buddy hasn't mutually revealed yet) must continue to
      show *no content* — this task does not change the privacy gate itself, only what
      renders once content is already permitted to be shown.
- [ ] A buddy's actual photo can be fetched and displayed once mutually revealed (new
      capability if it doesn't already exist — check `ImageFetching`/`Sources/Data/ImageStore.swift`
      for whether it can fetch an arbitrary post's image given `imagePath`, not just the
      viewer's own).
- [ ] `xcodebuild test -only-testing:SkyGridTests` exits 0, all tests green (baseline: 209
      passed before this loop started — never let this regress; add tests for any new pure
      logic, e.g. image-fetch/cache decision functions).
- [ ] `xcodebuild build -project SkyGrid.xcodeproj -scheme SkyGrid -configuration Release
      -destination 'generic/platform=iOS'` (run from `ios/`) succeeds with 0 errors.
- [ ] `cd ios && xcodegen generate` has been run if any new Swift file was added (check
      `git status` shows `project.pbxproj` updated to match).
- [ ] A dev-note exists at `dev-notes/photo-over-color-conversion_2026-08-14.md` documenting
      what changed, why (the pivot, dated), and any gotchas — following this repo's existing
      dev-notes convention (see other files in `dev-notes/` for the expected shape: 思考ログ・
      ハマりどころ・状態).

## Constraints / guardrails

- **Do not weaken or change `firestore.rules`'s privacy gate**
  (`hasPostedFor(localDate)` / `activeBuddy(uid)` in `ios/firestore.rules`). Mutual reveal
  itself — *when* a buddy's post becomes readable at all — is unchanged. Only *what is
  rendered once it's already readable* changes (color → photo). If achieving photo display
  requires a Storage Rules change (separate from Firestore rules — check
  `ios/storage.rules` if it exists) because photo bytes were previously never fetched
  client-side for buddies, that IS in scope, but keep it as narrow as the existing
  `hasPostedFor` gate — do not open broader access than the existing mutual-reveal logic
  already grants at the Firestore document level.
- Do not touch `ios/functions/`, `ios/firestore.rules`'s existing structure beyond what's
  needed for Storage read access, or anything already shipped/deployed this session (buddy
  push notifications, solo-morning paywall — those are done, leave them alone).
- Match this codebase's existing conventions: dense, reasoning-carrying doc comments; pure
  functions with injected `now`/dependencies where testable; `@testable import SkyGrid` +
  Swift Testing (`@Test`/`#expect`) for new test files; xcodegen-generated project (never
  hand-edit `project.pbxproj`).
- **Update stale doc comments you encounter that describe the old color-only design as
  current** (e.g. `BuddyTile.swift`'s existing comment "shows only their sky colour, never
  the photo itself" — this is now false and must be corrected, not left to mislead a future
  agent). Explain *why* it changed (date + one line), not just *that* it changed.
- git commit is pre-authorized (do it after each verified step). Do NOT push, deploy, or
  resubmit to App Store review — that is explicitly out of scope for this loop.
- Session cost for the *interactive* portion of this task has already run very high before
  handing off to this headless loop — be efficient. Prefer direct implementation over
  spawning many recon subagents once the "Known color-display sites" list below is confirmed
  accurate; only spawn a reviewer agent for the review gate (Phase 2 step 5) and an
  `architect`/`code-architect` agent only if a genuinely hard cross-cutting data-flow decision
  emerges that isn't already resolved by "Recon findings" below (e.g. the buddy-image-fetch
  capability, if it doesn't already exist, is exactly this kind of decision — get that one
  design pass right, once, before touching every call site).

## Recon findings (filled during Phase 1 — confirmed facts, don't re-derive)

**Known color-display sites (grep confirmed 2026-08-14, `ios/SkyGrid/Sources/` — verify each still
applies, this repo changes daily):**
- `Sources/Today/BuddyTile.swift` — buddy strip on Today screen. Currently: a `Circle()` filled
  with `post.skyColor.color` when `.posted`, gray placeholder otherwise. Never fetches/shows
  the buddy's actual image. Doc comment explicitly says "never the photo itself" — must be
  corrected.
- `Sources/Today/WeekRhythmView.swift` — the "THIS WEEK" 7-cell rhythm row. Currently even
  simpler than per-day color: `day.hasPosted ? accent.color : SGT.ghostFaint` — one single
  fixed accent color for every posted day, not even each day's own sky color. Needs each
  day's actual photo (the viewer's own week — no buddy privacy concern here, this is always
  the viewer's own posts).
- `Sources/Grid/` — the 365-cell year grid and its exports. Files: `GridArchiveView.swift`,
  `GridCanvas.swift`, `SkyGridView.swift`, `ShareCardRenderer.swift`,
  `SkyGridExportView.swift`, `MorningCardExportView.swift`, `AppStoreIdentityExportView.swift`,
  `ContactSheetLayout.swift`, `GridLayoutMath.swift`. **Not yet read this session — first
  loop iteration should confirm what each currently renders** (VISION.md at repo root calls
  this "365マスの色モザイク" / a 365-cell *color* mosaic, so assume color-swatch rendering
  until confirmed otherwise per file).
- `Sources/Milestone/MilestoneMoment.swift` / `MilestoneView.swift` — **may already show an
  actual photo.** `RootView.swift`'s `resolvePostCaptureMoment` constructs
  `MilestoneMoment(milestone:, post:, photo: localPhoto(for: post), handle:)` where
  `localPhoto(for:)` reads a `UIImage?` from local disk. Confirm whether `MilestoneView`
  actually renders that `photo` field or ignores it in favor of `post.skyColor`. If it
  already shows the photo, this screen may need no change (or only a minor fallback-path
  fix) — don't assume work is needed here without checking first.
- `Sources/DesignSystem/SkyColorDisplay.swift`, `ExportTheme.swift`, `Theme.swift` — likely
  shared color-rendering helpers/tokens used by several of the above. Check whether these are
  reusable as-is (photo views probably still want some color use for backgrounds/accents —
  the goal is "show the photo", not necessarily "delete every use of SkyColor" — e.g. a
  photo's dominant color could remain a legitimate *accent/background* behind the image,
  consistent with `Sources/App/SkyGridApp.swift`'s and `Sources/Today/TodayView.swift`'s
  existing pattern of using `accentColor` derived from the day's sky as ambient tint. Use
  judgment: replace color-*as-content* with photo, keep color-*as-accent* where it already
  serves that separate purpose.

**Existing "shows the viewer's own real photo already" reference implementation — read this
first, it's the pattern to replicate for buddies/grid:**
- `Sources/Today/TodayView.swift`'s `morningRecord`/today-photo-card path, and
  `Sources/Data/ImageStore.swift` (`ImageFetching` protocol lives here, not in a separate
  `ImageFetching.swift` file — confirmed via grep, contains `pendingImageData`/
  `cachedImageData` static helpers per `RootView.localPhoto(for:)`'s usage). Confirm whether
  `ImageFetching`/`ImageStore` can fetch *any* post's image by `imagePath`/`thumbPath`
  (needed for buddy photos) or only the signed-in viewer's own local pending/cached files —
  this is the one design question worth getting right before touching every call site
  (see Definition of Done's second checkbox).

**Firestore/Storage privacy model (already understood, do not re-derive):**
`ios/firestore.rules`'s `posts/{localDate}` sub-collection already permits a buddy to read
the **entire post document** (including `imagePath`/`thumbPath` fields) once
`activeBuddy(uid) && hasPostedFor(localDate)` — the mutual-reveal gate is at the Firestore
document level, not per-field. So the *data* has always been technically reachable; only the
*client's choice not to fetch/render the image* enforced "color only." Whether Firebase
**Storage** rules (separate service, check `ios/storage.rules` if present) currently allow a
buddy's client to download the actual image bytes needs verifying — if Storage rules are
narrower than Firestore rules (e.g. owner-only), that is the actual blocker to fix, scoped
exactly to "a mutually-revealed buddy may download this specific image," mirroring the
Firestore `hasPostedFor` condition as closely as Storage rules syntax allows.

## TODO / progress (the loop maintains this)

- [x] Confirm `ImageFetching`/`ImageStore` capability and Storage rules — **already fully
      built**: `FirebaseImageStore.fetchImage(path:)` routes through the `imageDownloadURL`
      Cloud Function callable (`ios/functions/src/index.ts`), which gates a buddy's photo
      bytes behind the exact same `isActiveBuddy && hasPostedToday` check
      `firestore.rules` uses for the post document. No backend/Storage-rules work needed.
- [x] `Sources/Today/BuddyTile.swift` — now renders the buddy's actual photo (via new
      `ThumbnailLoader`) once revealed, falling back to `skyColor` while loading or on
      fetch failure. Stale "never the photo itself" doc comment corrected with dated
      design-history note.
- [x] `Sources/Today/WeekRhythmView.swift` — now renders each day's actual photo (always
      the viewer's own — no privacy gate applies). Required widening
      `WeekRhythmCalculator.summarize`'s signature from `postedDays: [LocalDate]` to
      `posts: [SkyPost]` and adding `thumbPath: String?` to `WeekRhythmDay` — done, one
      caller (`TodayViewModel`) and its test file updated.
- [x] `Sources/Grid/*` — **already fully photo-based**, confirmed by reading
      `GridCanvas.swift` (doc comment explicitly states "Each loaded cell is the user's
      actual sky photo"), `GridArchiveView.swift` (`GridArchiveViewModel.loadThumbnail`
      already does the local→cache→remote fetch chain `ThumbnailLoader` now generalizes),
      and `SkyGridExportView.swift`/`ShareCardRenderer.swift` (doc comment: "Draws real
      photos, matching every other place a day's sky is shown"). This was done in a
      2026-08-08 commit, predating this session — the repo-root `VISION.md`'s "365マスの
      色モザイク" description was simply stale documentation of an already-superseded
      design. No changes needed.
- [x] `Sources/Milestone/*` — **already fully photo-based**. `MilestoneView` passes
      `moment.photo` into `MorningCardExportView`, which shows the actual photo with
      `skyColor` only as a legitimate fallback-when-photo-is-nil (its own doc comment:
      "Not an invented fallback: skyColor is the colour extracted from this exact
      morning's photo"). No changes needed.
- [x] Storage rules change — **not needed**, see first item above.
- [x] Correct stale "never the photo itself" doc comments — done in `BuddyTile.swift`.
- [x] Tests green (211/211, up from 209 baseline), Release build green (0 errors, 2
      pre-existing unrelated warnings), xcodegen run for the new `ThumbnailLoader.swift`.
- [ ] Independent review gate (swift-reviewer, sonnet) dispatched — pending result.
- [ ] Write `dev-notes/photo-over-color-conversion_2026-08-14.md` (after review).
- [ ] Final commit (scoped precisely to SkyGrid files — do NOT `git add -A`, this repo has
      a concurrent, unrelated session actively writing to `videos/joespov-skygrid-remix/`;
      an earlier checkpoint this loop made swept those files in by accident and had to be
      reset — stage explicit paths only).

## Scope note (discovered during implementation, 2026-08-14)

The actual remaining work was far smaller than the original recon assumed: **Grid,
Milestone, and share-card exports were already fully converted to photo display**, most of
it in a 2026-08-08 commit predating this pivot conversation entirely. Only `BuddyTile` and
`WeekRhythmView` were still color-only. The backend/privacy-gate design question was also
already resolved (`imageDownloadURL` callable). This TODO list is being closed out in a
single focused pass rather than 20 loop iterations as a result — see the corresponding
dev-note for the full account.

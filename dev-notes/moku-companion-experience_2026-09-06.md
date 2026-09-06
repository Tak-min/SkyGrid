# Moku companion experience — handoff and correction pass

date: 2026-09-06
status: uncommitted working tree; debug build green, unit suite green, UI suite unchanged

## Why this note exists

The `.loop/moku-experience` run was started under Codex and stopped part-way on an
OpenAI usage limit, not on completion — its `state.json` still said "iteration 1".
The tree was left dirty, mid-build, with a compiler failure in the log. Anyone picking
this up later needs to know which parts were finished, which were wrong, and which
problems here predate the pass.

## What the pass does

One expressive Moku per scene; one owner for post-capture full-screen moments; image
decoding off the main actor with in-flight coalescing; bounded haptics; first-experience
duration instrumentation. See `.loop/moku-experience/VISION.md` for the brief and its
Definition of Done.

## Things that cost real time here — read before repeating them

- **The `xcodebuild` command in AGENTS.md does not run as written.** It names
  `iPhone 17 Pro`; this machine currently only has `iPhone 17`. The failure text is
  "Unable to find a device matching the provided destination specifier", which reads
  like a project problem and is not one. Check `xcodebuild -showdestinations` first.
- **A compile failure with no `error:` line is usually a stale project file.** Codex's
  logged swift-frontend failure did not reproduce: `xcodegen generate` fixed it. New
  `.swift` files need a regenerate before the project sees them.
- **`/` shows 99% full on this Mac and that is normal.** It is the sealed read-only
  system volume. The volume that matters is `/System/Volumes/Data`. A previous session
  reported a disk emergency off the wrong number.
- **`xcrun simctl io recordVideo` truncates here.** It returned ~6s clips regardless of
  the requested duration, so the leap animation was never captured end to end. Static
  screenshots plus the live-motion UI test are what exist as motion evidence.
- **Do not run a review agent's build against the same `-derivedDataPath` while your own
  test run is going.** It produced a phantom `** TEST FAILED **` with no failing test.

## The buddies surface, second pass

Seven UI tests were failing, identically on a clean worktree at HEAD. Chasing them by
actually rendering the screens — rather than by reading the assertions — turned up three
real defects that no test covered and no scenario could reach.

- **The empty circle could not be rendered at all.** Every buddies audit scenario shipped
  two accepted buddies, so `BuddyRitualCard`'s expanded three-step explainer — the state a
  brand-new account opens on, and the one that has to sell the whole buddy loop — had never
  been looked at. Added the `buddies-empty` scenario.
- **A brand-new account saw "Preparing your invite…" stacked on top of its finished invite
  card.** Two branches in the same `List` section were both true at once: an empty-circle
  placeholder, and `InviteLinkCard`, which owns its own `.loading` state. Only an account
  with an empty circle reached it, which is exactly the account nobody could render.
- **The Share button was white-on-white in dark mode.** `.tint(SGT.ink)` on a
  `.borderedProminent` control uses a *text* token as a *fill*: near-black in light,
  near-white in dark, against `borderedProminent`'s automatic white label. Three sites had
  it (`InviteLinkCard`, and both prominent buttons in `InviteClaimView`); all now use the
  accent/accentInk pair every other primary action in the app uses.

The tests themselves were stale in ways that mostly encoded design changes: the section
header is "YOUR CIRCLE" not "YOUR BUDDIES"; handle requests moved behind a
`DisclosureGroup` so their field is not in the hierarchy until expanded; the archive header
prints a bare count, not "20 / 365"; the claimed handle is no longer echoed on this screen.
Each assertion was retargeted at what the screen now actually guarantees.

**Left as an open product question**: an account that has buddies but no handle is offered
neither handle claiming nor an invite card — `HandleClaimView` is gated on the circle being
empty, and both the invite card and the handle-request disclosure are gated on already
holding a handle. That combination is a dead end. Whether it is reachable in production
depends on whether a link-claimed buddy can precede a handle, which is a backend question,
so the gating was left alone rather than guessed at.

## Pre-existing, deliberately not fixed

- **Two Dynamic Type gaps.** `CameraStage`'s header is a fixed `.frame(height: 52)`
  holding uncapped `SGFont.caption` text plus a 44pt button, and the `Sky Grid` /
  `Day one` / `Keep one morning sky.` headlines use bare `.system(size: 34/42)` which
  does not scale at all. The diff only *moved* those lines. Both touch the visual
  identity the brief says to preserve, so they are the owner's call.

## Corrections made on top of Codex's work

- Camera live screen rendered **two** Moku (header mark plus the expressive one in the
  shutter row). Removed the header mark.
- `Haptics.enabled` gated every haptic on `!UIAccessibility.isReduceMotionEnabled`,
  silently regressing the shipped `postCompleted` confirmation for those users. Reduce
  Motion is not a haptic preference. Character-play haptics stay gated at their own call
  site in `MokuView`.
- Reduce Motion also made the Moku tap a **dead control** — no animation and no haptic —
  while both screens still said "Tap Moku to say hello". The acknowledgement now fires
  before the motion gate.
- Welcome screen: the 3D-rotated mosaic projected past its layout bounds and collided
  with its caption, illegible in dark mode. The container now reserves the projected depth.
- `armDailyReward` wrote `lastRewardPlayedLocalDate` **before** presenting, while the
  moment itself lived in volatile `@State`. A process death in between permanently
  suppressed that day's reward: the flag said "played" when nothing had. The flag now
  writes only after the coordinator accepts the presentation. Residual and knowingly
  unfixed at the time: the moment was still lost if the process died first. Closed in a
  second pass — `PendingRewardStore` records the day, sky colour and thumbnail path (not
  the bytes: `UserDefaults` is the wrong home for tens of kilobytes, and the overlay
  already degrades to the recorded colour), and `restorePendingRewardIfNeeded` rebuilds it
  on launch, bounded to today and to the same `DailyRewardPolicy` gate so it can never
  manufacture a second celebration.
- `DisplayImagePipeline` only inserted into its memory cache on the code path of the
  caller that happened to start the load, gated on that caller's cancellation. A
  scrolling grid cancels those constantly, so already-downloaded, already-decoded bytes
  were thrown away. Insertion moved inside the coalesced flight, gated on `invalidated`
  alone. Decoding also moved off the actor — a synchronous CGImageSource decode there
  serialised every other call, including pure memory-cache hits.
- `TodayPhotoCard`'s progressive preview read `ImageFileStore` directly, outside the
  revocation boundary, and silently made the "waiting to sync" state unreachable — a
  blurred 320px tile stood in for the finished morning indefinitely. It now goes through
  `DisplayImagePipeline.cachedImage` (local-only, never falls back to the network) and
  keeps a visible badge while the photo is still a placeholder.
- Onboarding rail read `step.rawValue` (`wake_goal`) aloud to VoiceOver and announced an
  adjustable trait on the 4 steps where adjusting does nothing.

## The presentation lease, and one mistake worth recording

`RootPresentationCoordinator` is fail-closed: `dismiss()` only starts dismissal, and only
`didDismiss()` frees the slot. Correct for racing signals, but any presentation that
disappears without SwiftUI running `onDismiss` would block every later reward, paywall and
invite for the rest of the process.

The first attempt at a safety valve put `.onChange(of: destination)` on `todayFlow` — a
subtree that only exists while `destination == .today`, so leaving `.today` removed it in
the same update and the handler never ran. Dead code that looked like a fix. It now hangs
off `content(services:)` inside `body`.

The second attempt was worse: making `TodayView` report the share sheet's falling edge
from `onChange` rather than `onDismiss` fired it while UIKit was still animating the sheet
away, and the root immediately tried to present the next thing — which UIKit refuses
silently, leaving a presentation that never gets its own `onDismiss`. That turned a
theoretical lock into an easy one. The split now is: the flag follows both edges,
everything that *reacts* waits for `onDismiss`.

Both were caught by independent review, not by the test suite. If you change this area,
get it reviewed rather than trusting the tests.

## Verification actually run

- `xcodebuild build` — green, no new warnings (`artwork(motion:)`/`pose` are `nonisolated`
  so the keyframe closure does not break Swift 6 isolation).
- `SkyGridTests` — 301/301, including 3 new pipeline regression tests (cancelled starter
  still caches; `cachedImage` never reaches the network; `cachedImage` respects revocation)
  and 5 for `PendingRewardStore`.
- `SkyGridUITests` — all green, including the seven that were failing at HEAD.
- Real simulator screenshots in light, dark and Reduce Motion for onboarding, today and
  the live camera.

## Unverified

- Haptic quality on a physical device. Simulator only.
- The first-capture duration metric has no cohort data yet; `skygrid_first_experience_started`
  is the denominator and is logged once per install.

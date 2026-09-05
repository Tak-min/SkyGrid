# Playful redesign — closeout (2026-09-06)

## Outcome

SkyGrid's primary daily flow now makes one causal reward legible: framed sky capture → Moku's
bounded response → a disposable 24×24 pixel tile joins today's mosaic slot → only already
server-authorized buddy skies appear at settlement. The archive, buddies, alarm, settings,
purchase restore, safety/report/block, and account-deletion routes remain accessible after the
former primary `TabView` was removed.

## What changed and why

- Rebuilt the camera around a black stage with a rounded inset viewfinder and centered shutter;
  it follows the downloaded reference's geometry without using its branding.
- Added original Moku states, one daily success-only reward state machine, one haptic, seeded
  bounded confetti, a Reduce Motion shortcut, and no-PII reward started/completed events.
- Derived the reward tile only from the already-persisted local thumbnail. It is a display-only
  24×24 representation; the raw photo, thumbnail storage, and existing photo access controls
  are unchanged.
- Replaced peer tabs with contextual home routes so the morning capture and the yearly mosaic read
  as one flow rather than three destinations.
- At settlement, reuse the existing `TodayViewModel`/`BuddyTile` `.posted` state and a same-day
  `RewardRevealPolicy`; the redesign introduces neither a photo fetch nor a new reveal decision.
- Added deterministic DEBUG UI-audit states for every reward beat. They never publish a post or
  produce analytics/haptics, and the static peak keeps the production seeded confetti layout
  captureable. Real iPhone 17 attachments are saved in `screenshots/` for today, camera live/review,
  grid, buddies, and capture/pixel/landing/peak/settle reward frames.

## Verification

- Focused iPhone 17 UI audit: `testRewardAuditFramesRenderDeterministically` passed; five real
  1206×2622 attachments were exported to `screenshots/ui-audit-reward-*-after.png`.
- Focused iPhone 17 context audit: `testPlayfulRedesignContextAuditScreensRender` passed; fresh
  pre-capture, camera live/review, mosaic, and buddies attachments were exported to
  `screenshots/ui-audit-*-playful-redesign-after.png`.
- Full unit suite: `xcodebuild test -only-testing:SkyGridTests ...` passed, 284 tests / 51 suites.
- Release build: `xcodebuild build -configuration Release -destination 'generic/platform=iOS'`
  succeeded.
- Independent cumulative review initially found two HIGH issues: stale tab-bar UI tests and a
  too-brief/interruptible settled reward result. Both were fixed; the replacement two-test UI run
  passed. The reviewer found no remaining CRITICAL/HIGH privacy/reveal, exit-path, or Release-audit
  leakage issue.

## Measurement still outstanding

The product bet's wake-to-capture completion metric remains **unmeasured**: scheduled-alarm
occurrences that reach a saved capture within 15 minutes / scheduled-alarm occurrences. This work
adds the reward event distinctions needed for a future cohort read, but it does not establish the
alarm denominator or fabricate a result. The next evidence-producing step is the planned
seven-day TestFlight cohort comparison after release; shorten or remove celebration layers if the
median completion time worsens by 20% or more.

## Not done here

No Firebase deployment, App Store submission, push, production-data write, schema migration, or
destructive cleanup was performed.

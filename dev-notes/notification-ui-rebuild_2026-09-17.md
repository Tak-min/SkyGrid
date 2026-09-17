# Notification and daily-experience rebuild — 2026-09-17

## Decisions

- Buddy request and handle-request approval are distinct retryable events. Approval
  is emitted only for the atomic `pending -> accepted` transition marked
  `acceptanceKind: handle_request`; invite promotion cannot masquerade as approval.
- Notification send markers use a short `sending` lease and become `sent` only after
  at least one FCM success. Transient FCM failures release the lease and rethrow to
  the bounded trigger/scheduler retry path, including a resolved multicast response
  where every non-stale token failed. All-stale batches are deleted and treated as
  terminal. APNs collapse IDs remain the final duplicate-delivery guard.
- Personal and mutual streak reminders are evaluated at 20:00 in each recipient's
  valid timezone. Invalid timezone values fail closed. Mutual reminders require an
  accepted, unblocked friendship and no own post today.
- Weekly recap notification uses the existing seven-photo image renderer without a
  handle or invite link, then attaches the JPEG to the local notification. It is Pro
  only and limited to one notification in seven days.
- System notification banner background color is owned by iOS. Sky Grid controls the
  dark app icon and in-app surfaces, but must not claim it can force a black system
  banner.
- Revealed buddy posts open a free, vertically paged photo viewer. The separate
  side-by-side comparison remains Pro.
- The first Today visit uses a non-skippable coach layer over the real screen. Moku
  and its bubble share one layout container; dark limbs have a light outline.
- Onboarding cannot advance through swipe, accessibility increment, or skip buttons.
  It visits alarm setup and requires a handle plus a usable invite link/code before
  completion; Back remains available. Shared text contains both canonical URL and
  readable code, and Buddies accepts a pasted full share message or raw code.

## Validation completed

- iOS Simulator Debug build: passed after final integration.
- `SkyGridTests` full unit target: passed after final integration.
- Functions TypeScript lint/build and Node unit suite: passed after final integration
  (92 tests).
- UI-audit Today launch: passed after adding the shared `AppRouter` environment;
  walkthrough rendered over the real Today screen.
- `git diff --check`: passed.

## Environment-dependent checks

- Firestore emulator suite could not be rerun because this machine currently has no
  Java runtime. Earlier implementation work reported it green, but that is not treated
  as current verification.
- APNs/FCM delivery, notification image expansion, AlarmKit, camera capture, and social
  app handoff still require a signed real-device/backend smoke test.
- No Firebase deployment, App Store Connect change, commit, or push was performed.

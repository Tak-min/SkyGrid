# Canva Design Audit — Autonomous Brief (separate window)

## Goal
Document SkyGrid's current app design comprehensively in a Canva board, so the requester
(taku8) can review, in one place, every screen and how the workflows connect, without
opening the app or a simulator themselves.

## Scope / constraints (read before starting)
- **Do NOT modify any application source code.** This is a read-only documentation task
  with respect to the codebase. You may read Swift source files to understand navigation,
  but make zero edits under `ios/SkyGrid/Sources/` or anywhere else in the repo.
- **Do NOT run `git commit`, `git push`, or touch App Store Connect / RevenueCat.** Another
  Claude Code session is actively working on this same repo's App Store submission,
  paywall config, and a notification/audio fix in parallel. Stay entirely in
  simulator-screenshot + Canva territory. If you need to `git status`/`git diff` to
  understand code, that's fine (read-only), but do not stage or commit anything.
- **Prefer command/tool-driven simulator interaction over vision-based "computer use"
  click-by-coordinate automation.** Concretely:
  - Use the `xcodebuild` MCP tools (`session_show_defaults`, `discover_projs`,
    `list_schemes`, `boot_sim`, `build_run_sim`, `launch_app_sim`, `screenshot`,
    `list_sims`) as the primary path.
  - If the `argent` MCP tools are connected in this session (check via a tool search /
    the available-skills list — skills named `argent-ios-simulator-setup`,
    `argent-device-interact`, `argent-screenshot-diff`, `argent-test-ui-flow` reference
    them), prefer those for navigation: they drive the simulator by accessibility
    element reference or deep link rather than guessing pixel coordinates from a
    screenshot. Load the relevant skill first if so.
  - Only fall back to coordinate-based `computer`-style tapping if neither of the above
    can reach a given screen (e.g. a gesture-only interaction). Minimize this.
  - `xcrun simctl` via Bash is an acceptable fallback for booting sims / taking
    screenshots (`xcrun simctl io <udid> screenshot <path>`) if the MCP tools are
    unavailable for some reason.

## Steps
1. Get oriented: `session_show_defaults` (xcodebuild MCP) to see if a scheme/simulator is
   already configured for this project. If not, `discover_projs` under
   `/Users/taku8/Desktop/SkyGrid/ios`, `list_schemes`, then `boot_sim` an iPhone 15 Pro
   (or similar modern) simulator.
2. Build and run the SkyGrid app on that simulator (`build_run_sim`). If a build is
   already installed/running, `launch_app_sim` is enough — check first rather than
   rebuilding unnecessarily (a full rebuild is fine if needed, just don't assume it's
   required).
3. Map the screens before capturing: read
   `ios/SkyGrid/Sources/App/RootView.swift` (the central navigation/presentation
   coordinator — sheets, full-screen covers, tab/destination routing) and grep for
   `struct ... View` across `ios/SkyGrid/Sources/` to build a mental map of every
   reachable screen and which flow it belongs to. Known workflows to expect (confirm
   against the actual code, don't assume this list is complete or exactly right):
   - Onboarding (including the paywall step and the referral-code entry screen added
     recently)
   - Daily capture / camera flow
   - Today view (home)
   - Grid archive (yearly grid, share card export)
   - Buddies / friends list, buddy comparison view
   - Milestone / streak celebration overlay
   - Weekly recap (Pro feature) + its share card
   - Main paywall AND the "second-chance" paywall (a separate, one-time re-engagement
     paywall shown after closing the first one) — both are important to capture
     distinctly
   - Invite / share flows (invite link creation, claim screen)
   - Settings
   - Early-adopter retroactive-grant reveal screen (`EarlyAdopterRevealView` under
     `ios/SkyGrid/Sources/EarlyAdopter/`) — this is currently UNCOMMITTED work-in-progress
     from another session; it may or may not be buildable/reachable right now. If it's
     not reachable, skip it and note that in your final report rather than blocking on it.
   - Notification-triggered deep links, if reachable without a real push notification.
4. For each screen: navigate to it, take a screenshot, and save it with a clear
   descriptive filename indicating the workflow + screen (e.g.
   `01-onboarding-paywall.png`, `05-today-camera.png`). Save into
   `/Users/taku8/Desktop/SkyGrid/dev-notes/design-audit-screenshots_2026-09-16/`
   (create the directory).
5. Organize the screenshots into a Canva design using the Canva MCP tools
   (`mcp__canva__*`): create a design (a large multi-section board, or multiple pages —
   your call on whichever the Canva tools make easiest), upload each screenshot as an
   asset, and place them in a logical flow order grouped by workflow (Onboarding, Daily
   Capture, Grid/Archive, Social/Buddies, Monetization/Paywalls, Settings, etc.) with
   simple text labels identifying each screen and workflow, so the whole app's current
   design can be reviewed at a glance in one place.
6. When done, report a summary: how many screens captured, which workflows are covered,
   the Canva design's shareable link/URL, and any screens you could not reach and why
   (e.g. requires a real backend state, requires a push notification, requires a real
   IAP sandbox purchase, etc.).

## Notes
- This app is in Japanese/English bilingual localization; capture screens in whichever
  locale the simulator defaults to, no need to switch locales unless it's trivial to do.
- Work autonomously — this is non-destructive documentation work, proceed without asking
  for approval on routine steps. Only stop and ask if genuinely blocked (e.g. the app
  won't build at all).
- If you get stuck for more than a couple of attempts on any single blocker, report it in
  your final summary rather than looping indefinitely.

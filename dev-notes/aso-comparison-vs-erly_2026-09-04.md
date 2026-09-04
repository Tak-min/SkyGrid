# ASO comparison: SkyGrid vs. Erly — point-by-point, App Store listing vs. App Store listing

Date: 2026-09-04
Scope: `.loop/VISION.md` DoD item 7. Pure research/writing — no code, no screenshots, no ASC
changes made by this pass.
Method: (1) SkyGrid's *own* current listing verified two ways — the live App Store page
(`https://apps.apple.com/us/app/sky-grid/id6796222704`, fetched via WebFetch text-extraction
**and** a live Playwright screenshot + DOM image-URL dump on 2026-09-04) and the
`dev-notes/asc-*-submission_*.md` trail, which explicitly states the screenshots have been
**unchanged since version 1.0** (`asc-submission-status-audit_2026-08-09.md:36`, "概要
（description）とスクリーンショットは 1.0 から変更なし"). (2) Erly's listing verified live —
`https://apps.apple.com/us/app/erly-wake-up-early/id6751428380`, fetched the same two ways:
WebFetch for subtitle/description text, and a Playwright screenshot plus a DOM query that pulled
every screenshot image's full-resolution `mzstatic.com` URL, which were then downloaded with
`curl` and viewed directly (all 6, full resolution, in on-page order). Every claim below about
either app's actual listing traces to one of these two live fetches or to a dated dev-note; where
I could not verify something, it says `unverified`/`unmeasured` rather than guessing.

---

## 0. Headline

Erly's ASO strategy is not abstract "good ASO" — it is a screenshot sequence that sells one
concrete, demonstrable mechanic (a mission you must physically perform to kill the alarm) using
real, unstaged human photos, backed by a subtitle that names the exact pain (loud alarm, for
people who sleep through phone alarms) and a description built entirely around one repeated word:
**streak**. SkyGrid's listing sells a mood ("a quiet daily ritual") using synthetic marketing
copy laid over screenshots that are seven weeks stale — stale enough that they show UI states
`dev-notes/virality-stickiness-assessment_2026-09-04.md` already confirmed are fixed in code
(the blank `"___ : ___"` placeholder, bare buddy-name rows). The single highest-leverage,
lowest-risk ASO action available right now is not a redesign: it is re-shooting SkyGrid's six
screenshots against **current** code, because the live listing is currently marketing a version
of the app that no longer exists.

A second, unexpected finding: **Erly's own dismissal-mission menu includes "Picture of Sky — Step
outside and take a photo of the sky."** SkyGrid's entire core loop is a specific instance of a
mechanic Erly already ships as one option among six. This is a positioning fact, not a virality
fact — see §4.

---

## 1. Verified facts — SkyGrid's own current listing

| Field | Value | Source |
|---|---|---|
| App name | "Sky Grid: Morning & Wake" | live page title, WebFetch + Playwright, 2026-09-04 |
| Subtitle | **"Real alarm, daily sky ritual"** | live page (WebFetch); matches `dev-notes/gtm-review-and-v101-shipping_2026-08-08.md:147` (set for 1.0.1, still live) |
| Category | **Lifestyle** | live page, Playwright screenshot 2026-09-04 |
| Developer | Takumi Eto | live page |
| Ratings count | **No rating count/star average shown** (the metadata row that would carry it is blank where "AGE RATING / CATEGORY / DEVELOPER / LANGUAGE" appear) — consistent with a very new listing, effectively `unmeasured` from outside; product owner should confirm the actual count in ASC | Playwright screenshot 2026-09-04 |
| Description (live, full) | "Wake up, step outside, and capture the sky. No filters, no feed to scroll — just a quiet daily ritual that slowly becomes a year you can see. Sky Grid turns your morning into one small, honest ritual: step outside, capture the sky, and let the day begin. No filters. No feed to scroll. No pressure to look good — just **the true average color of the sky you actually saw, turned into one square in a mosaic that grows across the whole year.**" Then a "How It Works" list ending "Watch today's color take its place in this year's 365-square Sky Grid" and "Invite one trusted buddy — their morning stays blurred until you've shown up for yours too." | live page, WebFetch, 2026-09-04 |
| Promotional text | `None` as of the 2026-08-09 audit (`asc-submission-status-audit_2026-08-09.md:43`); current live state not re-confirmed this pass — `unverified` whether it was ever filled in after that audit flagged it | dev-note + live page (promo text isn't separately exposed by WebFetch's extraction) |
| Keywords (ASC keyword field, not public) | `unmeasured` — this field is never surfaced on the public listing page and no dev-note records its actual string value; every ASC note only says keywords were "carried over unchanged" from version to version, never what the string contains | grep across all `dev-notes/*.md`, no hit |
| Preview video | **None observed.** The first screenshot slot in the gallery is a static image (not a video thumbnail with a play control) in the live Playwright screenshot | Playwright screenshot 2026-09-04 |
| Screenshot count | 6 | live DOM query, 2026-09-04 |

### SkyGrid's actual screenshot order (live, verified 2026-09-04, filenames confirmed against `branding/mockups/app-store/*.png`)

Each screenshot is a 1206×2622 marketing card: eyebrow "SKY GRID" → bold headline → one-line
subhead → a real device-framed screenshot below. I opened every source PNG directly (not just the
thumbnail) to describe on-screen content.

1. **`01-today-one-sky-v1`** — "ONE SKY. EVERY MORNING." / "A quiet ritual for noticing the day."
   Screenshot: Today tab, pre-capture state. **This is the stale-UI screenshot.** It shows the
   placeholder card with "THIS MORNING" over two blank underscored lines (`"___ : ___"`-style
   dashes) — the exact defect `virality-stickiness-assessment_2026-09-04.md` §1 (B3) confirms was
   *already fixed in code* on 2026-09-04 (`TodayView.swift:225-251`, replaced by a streak-hero
   empty state). **SkyGrid's #1 screenshot — the first thing a browsing user sees — depicts a bug
   that no longer exists in the shipping app.**
2. **`00-skygrid-overview-v1`** — "YOUR SKY. YOUR YEAR." / "A quiet daily record, made one
   morning at a time." Screenshot: same Today-tab pre-capture state as #1 (same blank-placeholder
   card, same "Free / Not yet" badge, same "Morning alarm · 07:19" row). **Two of six screenshots
   show the same screen, both stale.**
3. **`02-grid-year-in-view-v1`** — "A YEAR OF MORNING SKIES." / "Watch your quiet record take
   shape." Screenshot: Grid tab, "2026 · 20/365" year strip + July month mosaic with real
   photo-derived color tiles. This screenshot is **not** stale — it reflects the post-B1 fixed
   grid layout — and is the strongest of the six on legibility grounds.
4. **`05-keep-the-whole-story-v1`** — "KEEP THE WHOLE STORY." / "Your newest 30 days stay free.
   Keep every sky when you're ready." Screenshot: the paywall (`SKY GRID PRO`, Annual $19.99 /
   Monthly $3.99 / Lifetime $59.99). **This is the paywall, placed at position 4 of 6** — ahead of
   onboarding and ahead of the buddy/social screen.
5. **`04-your-morning-your-rhythm-v1`** — "YOUR MORNING. YOUR RHYTHM." / "Start with a ritual that
   fits the way you wake." Screenshot: an onboarding question step ("Sky Grid · 01/06") behind a
   mostly-empty vertical column of colored squares and, below it, **"Keep one morning sky. / Its
   color becomes one quiet day in your grid."** — the literal averaged-*color* framing that the
   live description (above) still uses, and that `virality-stickiness-assessment_2026-09-04.md`
   §4.11 already flagged as factually stale: the product converted from averaged color to actual
   photographs in commit `82f39a3`, months before this screenshot and this listing description
   were written. **This is not just an onboarding-copy problem (as the prior dev-note framed it)
   — it is a live, public App Store claim about what the product does, and it is wrong.**
6. **`03-buddies-together-v1`** — "TWO SKIES. ONE MORNING." / "A private ritual, revealed
   together." Screenshot: Buddies tab, showing the explainer card ("Two skies, revealed
   together. Invite one trusted person...") over the invite form, with **"Mira"** and **"Ren"**
   as bare name rows below — exactly the B5 defect `virality-stickiness-assessment_2026-09-04.md`
   flags as still open in code ("no streak, no last-capture date, no handle, no reveal state...
   the row's only destination is Block/Report"). **SkyGrid's own most differentiated
   mechanic — the thing that makes it not just another photo-journal app — is shown last, in a
   still-broken-in-code state, on a screen that already tested as reading like "a generic
   wellness-app template."**

**Net: 2 of 6 screenshots (#1, #2) show a UI defect already fixed in code; 1 (#5) makes a factual
product claim that stopped being true months ago; 1 (#6) shows a screen whose specific defect
(bare rows, B5) is still open in code today. Only #3 is both accurate and strong. The listing is
not merely "could be better" — parts of it are actively wrong about the current product.**

---

## 2. Verified facts — Erly's current listing

`https://apps.apple.com/us/app/erly-wake-up-early/id6751428380`, Glacier Labs LLC.

| Field | Value |
|---|---|
| App name | "Erly: Wake Up Early" |
| Subtitle | **"Loud Alarm Clock for Sleepers"** |
| Category | **Health & Fitness** |
| Age rating | 13+ |
| Ratings | **16K ratings, 4.8★** — a mature, high-volume listing, not a comparable-stage competitor; treat every comparison below as "what a scaled listing looks like," not as an apples-to-apples stage comparison |
| Description (full, verified) | "Wake Up On Time. Every Time. Erly is the #1 accountability app for waking up early and staying consistent. Join many others who have broken free from snoozing and built unstoppable morning streaks... **SMART ALARMS** Alarms that won't turn off until you complete a mission. No snoozes. No excuses. **BUILD UNBREAKABLE STREAKS** Each morning is a clear win or loss with no excuses and no late submissions... **MAKE IT REAL** To keep your streak alive, record your wake-up before your target wake-up time. No shortcuts. No cheating... **LOCK IN YOUR GOALS** Once you're within 4 hours of your wake-up time, your goal locks in." |
| Preview video | **None observed** — first gallery slot is a static screenshot, no play affordance, in the live Playwright capture |
| Screenshot count | 6 |
| Keywords (ASC field) | `unmeasured` — not public, same limitation as SkyGrid |

### Erly's actual screenshot order (live, verified 2026-09-04, all 6 downloaded at full 1242×2688 and viewed directly)

1. **"Wake up early, every day"** — main/home screen. Top bar: "ERLY" wordmark, a **streak flame
   icon with the number 43**, a trophy icon. Below: a 7-day S–S row of check/dash circles (today
   already checked). Center: a large glowing purple orb (the tap-to-log affordance). Below that:
   **"Awake at 6:30 AM"** in large type, and a smaller **"Go to bed by 10:30 PM"** line. Bottom
   nav: Log Wake Up / Edit Time / History / More.
2. **"Set smart alarms that require a task"** — an "Alarms" list screen: "School" (Weekdays,
   6:00 AM) tagged with a red **"Push-Ups"** mission chip; "Positive Weekend" (Weekends, 6:30 AM)
   tagged with a purple **"Affirmation"** chip. Each row has its own mission type, visibly
   different per alarm.
3. **"Push ups, item search, and more"** — a "Choose a Mission" grid (title: "Complete a mission
   to turn off your alarm"), 6 visible tiles with emoji + name + one-line task description:
   **Push Ups** ("Complete push-ups for 15 seconds"), **Item Search** ("Find and photograph a
   random item"), **Bible Verse** ("Read a Bible verse out loud to begin your morning"),
   **Devotional** ("Photograph a Bible verse and read a devotional"), **Picture of Sky** ("Step
   outside and take a photo of the sky"), **Make Bed** ("Make your bed and take a photo of it").
4. **"Push ups to turn off your alarm"** — a real, unstaged first-person photo (not a mockup) of a
   person mid-push-up on a bedroom floor, overlaid with "Push-ups for 15s" and a countdown-style
   orange bell icon at the bottom. This is the proof-of-mechanic shot: it shows the *camera being
   used to verify a physical action*, not a UI screen.
5. **"Gamified accountability"** — an "Achievements" list: **Early Riser** (1 day streak, "The
   journey of a thousand mornings begins with a single sunrise"), **Dawn Seeker** (3 days),
   **Early Bird** (7 days, "A full week of committing to the mornings"), **Routine Builder**
   (10 days, "Double digits. Discipline outweighs desire for sleep."), and one more partially
   visible ("Morning Person"). Each has its own colored orb icon and a one-line, slightly wry
   copy voice.
6. **"Keep your streak alive"** — the alarm-ringing screen itself: "ERLY" wordmark, huge
   **"6:25 AM"** time, then **"43 / day streak"** directly below it, the same glowing orb, and a
   "Close" button at the very bottom (deliberately de-emphasized relative to the streak number).

**Net: every one of Erly's 6 screenshots shows a distinct, real, verifiable product moment. Two
(4, 6) are literally camera/lock-screen captures of the mechanic firing, not staged UI. The word
"streak" (or its number) appears in screenshots 1, 5, and 6 — three of six. Zero screenshots are
onboarding or paywall.**

---

## 3. Point-by-point comparison

| Lever | Erly (verified) | SkyGrid (verified) | Gap / recommendation |
|---|---|---|---|
| **Subtitle** | "Loud Alarm Clock for Sleepers" — names the *symptom* (you sleep through alarms) in searchable consumer language. | "Real alarm, daily sky ritual" — names the *mechanism* (a real AlarmKit alarm) plus a mood word ("ritual"). Not wrong, but it doesn't name a symptom or an outcome a searcher would type. | SkyGrid's AlarmKit-vs-notification distinction is real and defensible (`virality-stickiness-assessment_2026-09-04.md` calls Stage 1 "the app's strongest") but the subtitle spends its 30 characters on a claim ("real alarm") most searchers can't evaluate before installing, instead of a symptom they'd search for. Recommend testing **"Wake up. Prove it. Keep a streak."** or **"A real alarm you can't sleep through"** against the current subtitle — both name a symptom/outcome the way Erly's does, while keeping "real alarm" as the differentiator inside the phrase rather than as the whole phrase. |
| **Keywords field** | `unmeasured` (not public) | `unmeasured` (not public) — and, per dev-notes, never once recorded even internally; every ASC submission note says only "carried over unchanged." | Since neither is observable externally, this is the one lever this dev-note **cannot** compare point-by-point from outside data. Recommend: pull SkyGrid's actual current keyword string from ASC (`appStoreVersionLocalizations.keywords`, `dev-notes/tools/asc.py` already has the auth plumbing) as the first concrete follow-up, then set it deliberately around the symptom-language the subtitle test above validates (e.g. "wake up alarm, morning routine, habit streak, accountability, sunrise photo") rather than product-internal nouns ("sky," "grid," "mosaic") that no one searches. |
| **Screenshot 1** | Home screen mid-use: live streak (43), weekly check row, "Awake at 6:30 AM" — shows the *payoff state*, not the empty state. | "ONE SKY. EVERY MORNING." over the **pre-capture placeholder card**, which is the stale broken-glyph UI already fixed in code. | Concrete fix: re-shoot screenshot 1 against **current** `TodayView.swift` (post-B3), and lead with a **captured** morning (a real photo card + visible streak number), not the empty state. Erly's choice to open on a mid-streak, already-successful screen — not a cold-start screen — is deliberate and directly portable. |
| **Screenshot 2** | Alarms list showing **per-alarm mission tags** (Push-Ups / Affirmation) — demonstrates configurability and the mechanic together in one glance. | Duplicate of screenshot 1's same stale Today screen, different headline ("YOUR SKY. YOUR YEAR."). No new information. | This slot is currently wasted. Recommend replacing it with the Grid screenshot (currently #3) or, once DoD 5's multi-alarm work lands, an Alarms-list-style screenshot analogous to Erly's — SkyGrid does not yet have an equivalent screen to shoot before that ships. |
| **Screenshot 3** | Mission-picker grid — makes the alarm-dismissal mechanic legible as a *menu of choices*, which frames Erly as flexible rather than punishing. | Grid tab (2026 year strip + July mosaic) — SkyGrid's strongest, most accurate screenshot. | Keep this one essentially as-is; it is honest and legible. Consider moving it to position 2 (see reordering below). |
| **Screenshot 4** | Real unstaged photo of a person mid-push-up — camera-verified proof the mechanic is real, not a mockup. | The paywall (`SKY GRID PRO`, pricing). | This is the starkest gap. Erly spends this slot proving its mechanic is real; SkyGrid spends the equivalent slot asking for money before showing its most differentiated feature (buddies) at all. Recommend moving the paywall screenshot to position 6 (last, where a "keep the whole story" upsell reads as a natural close) and replacing position 4 with a **real captured-sky photo screenshot** — the Today "recorded" state, once D1's share button exists — which does for SkyGrid what Erly's push-up photo does: proves the artifact is a real photograph, not a synthetic gradient. |
| **Screenshot 5** | Achievements/streak list with named milestones and wry one-line copy ("Discipline outweighs desire for sleep") — turns the streak mechanic into content, not just a number. | Onboarding question screen with the stale "Keep one morning sky. / Its color becomes one quiet day in your grid." copy — **actively describes a product SkyGrid no longer is** (averaged color vs. real photos, per commit `82f39a3`). | Two separate fixes bundled in one slot: (a) SkyGrid already has `Milestone/StreakMilestone.swift`'s named thresholds (`[1, 7, 14, 30, 50, 100, 200, 365]`) and `MilestoneView.swift` — this is a ready-made analog to Erly's Achievements screenshot and should be shot from that screen, not from onboarding; (b) the "its color becomes" line must be rewritten everywhere it appears (App Store description **and** this screenshot **and** `WelcomeView.swift`) to describe an actual photograph, not a color. |
| **Screenshot 6** | The alarm-ringing screen itself, streak number directly under the time, "Close" visually de-emphasized — sells the *moment of friction* as the site of the payoff. | Buddies tab with bare "Mira" / "Ren" name rows (no streak, no capture state, no handle) — SkyGrid's most differentiated mechanic, shown last, in a screen whose own defect (B5) is still open in code. | If DoD 3's P0 buddy-row redesign (`virality-stickiness-assessment_2026-09-04.md` §7) ships before the next screenshot refresh, shoot this slot from the redesigned rows (streak + capture-state per buddy) rather than the current bare-name state — do not reshoot the current broken screen into the App Store listing a second time. Until that redesign ships, this is the one screenshot where "reshoot now" and "wait for DoD 3" genuinely conflict; recommend waiting, since reshooting a known-broken screen into a public listing is worse than leaving the current (also broken, but at least not *newly* broken) one up a few more weeks. |
| **Preview video** | **None observed** on either app. | **None observed.** | Not a gap — neither app uses this lever today. Given Erly proves its mechanic with a single still photo (screenshot 4) rather than video, a preview video is not obviously the next lever for either app; if SkyGrid does invest here later, the highest-value 15–30s cut (per Erly's own screenshot-4 logic) would be: alarm fires → user steps outside → captures real sky → sees streak increment → sealed buddy disc unseals. That is the whole loop in one continuous real capture, which is exactly the "prove it's real" move Erly makes with a still. |
| **Description framing** | Every section header is an imperative claim about *outcome* (SMART ALARMS, BUILD UNBREAKABLE STREAKS, MAKE IT REAL, SEE YOUR PROGRESS, LOCK IN YOUR GOALS) — no mention of what the UI looks like, entirely about what happens to *you*. | Leads with mood ("quiet daily ritual"), then explicitly states the mechanic is **color-averaging** — factually false against current code, and undersells the fact that SkyGrid keeps real photographs, which is a stronger, more concrete claim than a mood word. | Rewrite the live description's second sentence from "the true average color of the sky you actually saw, turned into one square" to something naming the actual artifact — e.g. "a real photo of the sky you actually saw, one square in a mosaic that grows across the whole year." This is a factual correction, not a stylistic one, and it can ship today (ASC `appStoreVersionLocalizations` description edits are not app-review-gated in the same way build changes are — confirm in ASC before assuming, but the promotional-text precedent in `asc-submission-status-audit_2026-08-09.md` shows non-build metadata can be edited without a new build). |

---

## 4. A finding outside the original brief, worth surfacing explicitly

**Erly already ships "Picture of Sky — Step outside and take a photo of the sky" as one of six
interchangeable alarm-dismissal missions** (screenshot 3, verified above). SkyGrid's entire
product is, mechanically, a specialized, socially-gated, year-long version of exactly that single
Erly mission. This has two implications, not one:

- **Positioning risk:** an ASO searcher who already has Erly and sees "step outside, photograph
  the sky" may read SkyGrid as "the thing Erly already does, minus the punch-you-awake mechanic."
  SkyGrid's actual differentiation is not the sky-photo action itself — it's (a) the year-long
  archive/mosaic Erly has no equivalent of, and (b) the buddy mutual-reveal gate Erly has no
  equivalent of. **The subtitle and description should lean harder into archive + social,
  precisely because the single-action mechanic is not unique.**
- **This is a claim about Erly's public listing content, not a claim about user overlap, market
  size, or which app "wins."** I have not measured whether SkyGrid and Erly compete for the same
  searcher intent — that would require keyword-overlap data (`unmeasured`, needs Apple Search Ads
  Manage Bids or a third-party ASO tool, neither available in this pass).

---

## 5. Recommended screenshot reorder for SkyGrid (bet, not a claim)

*Assumption:* Erly's ordering logic — payoff-state opener, mechanic-proof, social-proof-via-content
(achievements), friction-moment close, monetization pushed to the very end or omitted from the
gallery entirely (Erly's gallery has **no paywall screenshot at all** in its 6) — outperforms
SkyGrid's current opener-is-broken-UI / paywall-at-4-of-6 / social-mechanic-last ordering.

*Cheapest test:* re-shoot against current code in this order, keeping the existing marketing-card
template (`compose_store_marketing.swift` already does the compositing — extend it to 6 specs
instead of 3, or shoot the remaining 3 the same way `01`/`02`/`03` were evidently produced):

1. Today, **recorded** state (real photo card + streak number) — replaces stale placeholder.
2. Grid (`02-grid-year-in-view`, already good, unchanged).
3. Milestone/Achievements screen (`MilestoneView.swift`) — new, analogous to Erly's screenshot 5.
4. Buddies, **post-DoD-3-redesign** state (streak + capture-state per buddy row) — analogous to
   Erly's screenshot 1/2 combined; **do not shoot this before the B5 fix ships.**
5. Onboarding mechanic screen, rewritten copy (no "color" claim) — analogous to Erly's screenshot
   2/3 (shows the mechanic as a concept, not mid-product-tour).
6. Paywall (`05-keep-the-whole-story`, unchanged content, moved from position 4 to last).

*Exit condition:* this is an ordering hypothesis with no data behind it yet — if/when
`skygrid_invite_link_shared`, App Store impression-to-install conversion, or any ASC Product Page
Optimization (A/B) test data becomes available, defer to that data over this ordering. Apple's own
Product Page Optimization feature (`unverified` whether currently configured for this app — check
ASC before assuming) would let the two orderings (current vs. this proposal) be tested directly
against real impressions rather than argued from a competitor read.

---

## 6. What this pass could not verify (say so plainly)

- **Exact ASC keyword-field string for either app.** Not public, not recorded in any dev-note.
- **SkyGrid's current promotional-text field state** — flagged empty at the 2026-08-09 audit,
  not re-checked live this pass (WebFetch's markdown extraction does not reliably surface this
  field separately from the description).
- **Actual install/conversion impact of any recommendation above** — every recommendation in §3
  and §5 is a bet (per the kernel's claim-vs-bet discipline), not a measured result. No App Store
  Connect analytics access existed for this pass.
- **Keyword-overlap / competitive-intent data** between SkyGrid and Erly (§4) — would need Apple
  Search Ads or a third-party ASO tool (App Figures, Sensor Tower, AppTweak), none available here.
- **Whether Erly runs a Custom Product Page or Product Page Optimization test** — the listing
  fetched is whatever the default storefront serves; Erly may show different creative to different
  cohorts that this single fetch would not reveal.

---

*Primary evidence this pass is load-bearing on: live Playwright screenshots and DOM image-URL
dumps of both `apps.apple.com` listings (2026-09-04), the 6 full-resolution PNGs downloaded from
each app's `mzstatic.com` CDN and viewed directly, `dev-notes/asc-submission-status-audit_2026-08-09.md:36`
("screenshots unchanged since 1.0"), `dev-notes/gtm-review-and-v101-shipping_2026-08-08.md:147`
(subtitle set), `branding/mockups/app-store/*.png` + `branding/mockups/compose_store_marketing.swift`
(source of SkyGrid's submitted screenshot assets and 3 of 6 exact title/subtitle strings), and
`dev-notes/virality-stickiness-assessment_2026-09-04.md` (cross-referenced for code-verified UI
defect status, not re-derived).*

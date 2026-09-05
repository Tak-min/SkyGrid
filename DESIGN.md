# SkyGrid — Playful Reward Design System

**Status:** owner-approved current direction, 2026-09-05.

This section supersedes the earlier calm-capture and no-mascot/no-confetti rules for the playful
redesign. The earlier direction is preserved verbatim below as decision history; it is not an
implementation constraint where it conflicts with this section. Privacy, honest capture, raw-photo
preservation, accessibility, and non-competitive social boundaries remain in force.

## Product promise

Wake up, catch the real sky, and watch that morning become a playable piece of a world shared with
people who also showed up.

The interface must make one causal loop legible without explanation:

`alarm -> framed camera -> capture -> Moku reacts -> photo becomes a pixel tile -> tile lands in the mosaic -> permitted buddy skies reveal`

The captured sky is always the cause and the content. Mascot motion, confetti, streaks, and spring
physics are feedback for that action; none may become a separate reward economy.

## Reference policy

References are behavioral ingredients, not visual templates:

- From Brilliant: one unmistakable next action, large tactile controls, and success feedback that
  changes visible progress immediately.
- From Noom: one decision per step during first-run setup only. Repeated alarm setting must remain a
  one-tap confirmation or direct time edit, never a nightly questionnaire.
- From PostHog: a character may carry state and humor. Do not copy its hedgehog, silhouette, pose,
  line style, palette, copy voice, or developer-tool layout.
- From the downloaded Locket camera reference: use a black stage, a large inset rounded viewfinder,
  a prominent centered shutter, and compact surrounding controls. Do not copy its branding, yellow
  accent, social counters, or exact icon arrangement.

No learning-path nodes, generic achievement dashboards, bento grids, decorative card stacks,
levels, coins, leaderboards, or points.

## Experience dials

- **ENERGY 4 / 5 — expressive:** capture success is visibly joyful, including every-morning
  confetti. Utility and safety surfaces stay direct rather than decorative.
- **RHYTHM 4 / 5 — staged:** calm anticipation, one decisive capture, a short reward peak, then a
  settled mosaic. The product should breathe between beats instead of moving continuously.
- **MOTION 4 / 5 — causal:** spatial motion is a core explanatory layer. It is bounded, cancellable,
  deterministic, and never idle spectacle.
- **DENSITY 2 / 5 — focused:** one dominant object and one dominant action per state. Playfulness
  comes from character and physics, not more controls.

## Information architecture

The primary daily experience is a stateful world, not a tab collection:

1. **Pre-capture:** today's empty mosaic slot, Moku, alarm status, sealed buddy presence, and one
   capture action.
2. **Camera:** black stage with an inset live viewfinder and central shutter. Permission, failure,
   retake, and cancel paths remain reachable.
3. **Reward:** the successful photo pixelates and lands in today's slot; Moku celebrates; confetti
   marks the landing; only server-authorized buddy photos may reveal.
4. **Settled mosaic:** the growing photo mosaic is home. A day opens its own morning detail rather
   than navigating to a generic feed.
5. **Night:** the same world shows tomorrow's empty slot and a direct alarm-time action; it is a
   visual state, not a repeated onboarding flow.

Archive, invite/buddies, alarm editing, purchases, restore, settings, account deletion, report, and
block remain reachable contextually through sheets, day details, and explicit utility affordances.
Removing the general-purpose tab bar never authorizes removing these routes.

## Shape and layout

- **Camera stage:** near-black edge-to-edge ground. The viewfinder is inset on all sides, vertically
  dominant, and uses a 32 pt continuous corner radius. It must read as a physical window, not a card.
- **Primary controls:** minimum 56 pt height; the shutter is 76-84 pt. Press feedback uses a brief
  0.96 scale plus a 2 pt downward translation, returning with a spring. Controls maintain at least
  a 44x44 pt accessibility target.
- **Mosaic tiles:** square, tightly related, and allowed to touch. Empty, captured, sealed, and
  revealed states differ by content and edge treatment, not by unrelated card containers.
- **Corners:** 18-24 pt for action surfaces, 32 pt for the camera window, and 8-12 pt for individual
  mosaic tiles shown at detail scale. Avoid applying one radius to every object.
- **Spacing:** use an 8 pt base rhythm. Default screen gutters are 20 pt; reward staging may use the
  full black canvas. Large empty space must frame the active object, not compensate for missing
  content.
- **Cards:** use only when an actual object has a boundary, such as the live viewfinder or a day
  detail. Do not wrap headings, explanatory copy, rows, or groups in cards by default.

## Color and type

The photograph supplies most color. Fixed UI colors provide contrast and character:

- **Night Stage** `#080A0F`: camera and reward ground.
- **Night Stage** is also the settled mosaic and utility ground. There is no
  light-mode or paper-mode product shell; real sky tiles provide the changing
  color inside the world.
- **Cloud** `#F4F1EA`: high-contrast ink and quiet controls on the night stage.
- **Dawn Spark** `#FF6846`: primary playful accent and Moku's pre-capture spark; never a substitute
  for real sky content.
- **Open Sky** `#58C7F3`: secondary active state.

Do not introduce Locket yellow or generic purple/blue product gradients. A gradient is allowed only
when sampled from a real captured sky or when representing a transition between two real sky tiles.
All text and controls must meet WCAG AA contrast in their rendered state.

Use the system rounded/sans family for actions, numbers, captions, and every persistent screen
headline. The New York serif is retained only for fixed exported photo artifacts after capture; it
does not appear in interactive UI.

## Pixel-art contract

- The original photograph remains intact for the user's day detail and authorized buddy viewing.
- The mosaic uses a derived square tile, initially **24x24 logical color samples**, upscaled with
  nearest-neighbor interpolation. This is intentionally more legible as pixel art than 100x100 at
  phone scale.
- The implementation may compare 16, 24, and 32 samples in audit fixtures, but it must choose one
  resolution consistently before release. Never mix arbitrary resolutions in the same mosaic.
- Pixelation is revealed as a transformation from the actual crop; do not replace the image with a
  random palette, generated illustration, or average-color placeholder.
- Missing and failed images stay visibly absent. Never fabricate a sky for visual completeness.

## Mascot contract — Moku

**Moku** is SkyGrid's original tile spirit. The name is a working product name, but the following
visual and behavioral identity is binding until explicitly revised.

- **Silhouette:** an asymmetric rounded 4x4-pixel cluster with one offset corner, two square ink
  eyes, and short line-free pixel limbs. It is neither an animal nor a cloud outline and has no
  spikes, fur, snout, clothing, or PostHog-like hedgehog traits.
- **Material:** before capture, Moku is mostly Night Stage/Cloud with one Dawn Spark pixel. After
  capture, its body briefly accepts colors sampled from today's derived sky tile.
- **Role:** before capture, Moku points attention toward today's empty slot or shutter. During
  processing, it watches the real transformation. After landing, it jumps once and settles beside
  the new tile. It never obscures the sky or becomes the primary navigation control.
- **Emotion set:** waiting, ready, bracing, delight, settled, and recoverable error. Avoid shame,
  sadness, anger, pleading, streak-loss guilt, or manipulative disappointment.
- **Voice:** optional and sparse. One short sentence maximum, concrete and morning-specific. No
  generic coaching, praise inflation, baby talk, or constant speech bubbles.
- **State truth:** Moku may react only to observed state. It cannot celebrate before publish success,
  imply a buddy posted when reads are denied, or present an upload failure as completion.

## Daily reward motion contract

The reward begins only after the app has a successfully saved capture. It plays at most once for that
successful post and has a target duration of **1.4-1.8 seconds**:

| Beat | Target time | Required meaning |
|---|---:|---|
| Capture confirmation | 0-180 ms | Viewfinder compresses once; Moku braces. No success claim yet. |
| Pixel derivation | 180-560 ms | The real photo resolves into the derived tile. Moku follows it. |
| Mosaic landing | 560-1,050 ms | The tile travels to the actual current-day slot and snaps into place. |
| Reward peak | 900-1,350 ms | One success haptic, Moku's single jump, and 18-28 square confetti pieces mark the landing. |
| Buddy reveal / settle | 1,200-1,800 ms | Authorized buddy tiles unseal; otherwise sealed/not-yet states remain truthful. Controls settle. |

Rules:

- Confetti uses squares sampled from today's tile plus Dawn Spark/Cloud, emits from the landing slot,
  falls once, and is removed. No endless emitters, fireworks, coins, stars, or emoji particles.
- The capture-to-tile path is visually dominant. Confetti and Moku must not cover the transformation,
  shutter recovery, error actions, or buddy photos.
- One success haptic occurs at landing. Button press haptics are separate light feedback; do not stack
  multiple success haptics.
- A milestone may extend the settled state, but it must not replay the daily transformation or
  trigger a second competing full-screen celebration.
- Interruption, backgrounding, or view recreation must resolve to the truthful settled state without
  replaying the reward or losing the saved post.
- Upload/publish failure stops before the reward peak and presents a recoverable action. Confetti is
  evidence of success and must never fire speculatively.

## Reduce Motion and accessibility

With Reduce Motion enabled:

- Replace spatial travel, bounce, particle movement, and scale springs with a 200 ms opacity/content
  transition into the completed mosaic state.
- Show a static square-pixel halo for up to 500 ms instead of moving confetti; switch Moku directly
  from bracing to settled delight.
- Preserve the same causal order and success haptic unless system haptics are disabled.
- Announce one concise VoiceOver result after settlement, including capture saved and the number of
  buddy skies revealed when nonzero. Decorative mascot/confetti elements are hidden from VoiceOver.

Dynamic Type must not move the shutter off-screen or cover the live viewfinder. State must never be
communicated by color or motion alone. All animated controls retain stable accessibility labels and
identifiers across transitions.

## Social and privacy boundary

- Raw buddy photos render only after the existing server-authoritative read succeeds. Animation may
  consume `sealed`, `posted`, and `notYet`; it may not infer permission from local capture state.
- A denied read remains sealed and visually distinct from a verified "not yet" response.
- Moku and copy never name, count, or celebrate a buddy whose state has not been authorized.
- The social surface stays a closed circle, not an infinite public feed. No ranking, comparative
  streak, public discovery, or pressure copy.

## Validation criteria

A design-system implementation is conforming only when:

- A muted video makes the capture -> pixel tile -> mosaic causal chain understandable without copy.
- The reward starts only after saved-capture success and completes in under 1.8 seconds in the normal
  path.
- Reduce Motion reaches the same settled state without translation, bounce, or moving particles.
- Fresh audit captures exist for pre-capture, camera/review, reward, mosaic, and each buddy reveal
  state; synthetic photos are clearly identified as fixtures.
- At iPhone 17 size, the viewfinder remains visibly inset, the shutter target is at least 76 pt, no
  primary content is hidden by system insets, and all text/control contrast passes AA.
- Privacy tests continue to prove that no buddy image bytes are available before the read gate.

---

# Historical direction — superseded where it conflicts above

The following 2026-09-05 agent draft is preserved for decision lineage. It was not owner-approved.
Its quiet-capture, low-motion, no-mascot, and no-confetti implications are explicitly superseded by
the owner-approved playful reward direction above. Its honest-photo, private-sharing, restrained
competition, and sky-as-content principles still apply where compatible.

**Authorship note (R-37 disclosure, per `.loop/antislop/antislop.md`):** this file was drafted
by the agent from what is already established in the shipped app and prior dev-notes
(`dev-notes/virality-stickiness-assessment_2026-09-04.md`, `dev-notes/critical-design-audit_
2026-09-05.md`), not invented from scratch — but it has not been reviewed/approved by the owner
as their own words. Treat it as a first draft to correct, not a final brief. Until the owner
edits it, every "why" below is the agent's best reconstruction of intent from real screenshots
and existing product copy, not a confirmed brand decision.

## Identity, one line

A private, unhurried record of the sky you actually saw this morning — the anti-Instagram: no
filters, no choosing your best shot, one honest photo a day, shared only with people who also
showed up.

## Dials (core Part 3)

**ENERGY 1 (Calm)** — closer to GOV.UK/Linear than an agency portfolio. The product's whole
pitch is "a calmer morning"; a bold, loud interface would contradict its own premise.
**RHYTHM 2 (Balanced, with real breaks)** — NOT uniform. The current failure (see the audit) is
that RHYTHM has collapsed toward 1 by accident: hero screens (Today, onboarding welcome,
share-year) have real composition, but Buddies/Settings/list screens all default to the same
card-stack shape. RHYTHM 2 means those screens need their own considered layout, not more
decoration on the existing template.
**MOTION 1 (Hover/transition only)** — a calm-morning product should not have attention-seeking
motion. Reveal/unlock moments (mutual reveal, streak increment) are the one place a deliberate,
purposeful transition earns its place; everything else stays still.

## Palette — why blue/orange, not a slop tell

The blue-to-orange gradient family (dawn/dusk sky tones) is **not** a decorative default; it is
literally the product's subject matter — each cell in the grid is a real captured sky color. This
is the R-31 "one-line reason" for the palette's existence: **the color IS the content, not a
brand accent applied on top of it.** Per `antislop.md` R-01, a palette is only a slop tell when
it's the model's default with no stated purpose — this one has a purpose, and it should not be
replaced with a generic "safe" 2-3-color system for its own sake.

**What the critical-design-audit actually found wrong is execution, not color choice**:
- The gradient is used at uniformly low saturation/softness everywhere (onboarding preview,
  Today's hero card, the grid) — this reads as the antislop "Sterile Default via over-softening"
  failure, not the "harsh default gradient" failure. The fix is to let saturation/contrast vary
  by context (e.g. a more saturated, confident treatment on the single most important card of
  the day vs. muted for a 31-day archive grid), not to abandon the palette.
- Cream/greige (`#F5F1E8`-ish ground, muted taupe cards) is the actual **neutral base**, and it is
  currently the *only* differentiator between "hero" and "connective tissue" screens — Buddies,
  Settings, and list rows use the identical cream ground + identical greige card with no second
  visual device (no photo, no per-person color, no typographic contrast). That is the real
  "sterile default"/no-identity failure this loop should fix, per R-20 and the audit's cross-
  cutting finding #1.

**Core palette, stated explicitly (R-29)**: cream/off-white (ground), warm taupe/greige (surface
cards), near-black (text, primary CTA) as the 3 neutrals; the sky-gradient (blue↔orange↔tan) as
the *one* accent family, reserved for actual sky-color data (grid cells, hero card backgrounds,
share cards) — never used as decorative chrome on rows, buttons, or badges that have nothing to
do with a real captured sky.

## Typography

Serif display (the "Keep one morning sky." headline family) for the emotional/hero moments;
system sans for functional UI (buttons, list rows, form labels). The current failure per the
audit is not the pairing itself (a serif-for-editorial + sans-for-utility split is a legitimate,
common craft pattern) but its **inconsistent application** — Settings pairs a heavy editorial
serif headline with a purely mechanical list, which reads as borrowed rather than intentional.
Reserve the serif voice for moments that are actually emotional (streak milestones, the reveal
moment, share cards); keep utility screens in sans throughout, headline included.

## Identity motif (Part 3, "one repeated, specific pattern")

The grid-of-colored-tiles motif (seen in onboarding, the year archive, and share cards) is the
strongest and most specific identity element in the app — it should be the thing extended into
under-designed screens, not a new motif invented on top. E.g. a buddy's reveal-gate state could
borrow the tile language (a small colored/sealed tile per person) instead of the current
generic gray-circle-plus-padlock, which has no relationship to the rest of the app's visual
vocabulary at all.

## What this file does NOT decide

Onboarding step count, the pace/frequency cut, and any new feature scope are product decisions,
not design-direction ones — this file is a filter/style anchor only, per `antislop.md`'s own
boundary rule (design direction is not a command to build things, only a "how it should look and
feel" reference).

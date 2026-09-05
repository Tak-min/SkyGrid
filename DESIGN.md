# SkyGrid — Design Direction

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

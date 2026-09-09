# PRODUCT-MODEL — Sky Grid website

Updated: 2026-09-09. Scope: waitlist/ only.

## Observed flow
`site/index.html` links to the live App Store listing, support, terms, and privacy.
`src/legalRedirect.ts` consolidates the legacy legal host onto skygrid.my with 301 redirects.

## Measurement
Bio-link traffic by platform and campaign phase: **unmeasured before 2026-09-09**.
`GET /get/{placement}` now counts App Store redirect GETs by placement without storing
IP addresses, user agents, cookies, or other request metadata. This denominator is
redirect GETs, not post views, unique people, App Store page views, or downloads.

Bet: placement-level counts are sufficient to compare broad TikTok/Instagram phases.
The cheapest test is to assign one bio URL per platform/phase and compare counts with
the corresponding posting windows. Stop treating this attribution as useful if link
previews/bots or manual checks materially dominate the small traffic volume.

## Decision
Owner requested 1.0.5 parity before automatic approval release. Source: read-only
`asc localizations list --version 56034449-fb7b-48f9-816e-fdcec37a650e --locale en-US --output json`.
Free: daily captures, buddies, alarms, rolling newest 30 days of photos.
Pro: full photo archive and full-year share card. Revisit when store claims change.

## Deployment
Main site: `npm run deploy` (wrangler.toml, skygrid-waitlist).
Legacy redirects: `npx wrangler deploy --config wrangler.legal.toml --keep-vars`.
The legal configuration intentionally has no main-site domain or D1 binding.
Previous legal version: 64830b70-2263-4ccb-a3ee-b2d7bb8d37bd.
Verify public pages and image hashes with `python3 scripts/verify-site.py`.

## Verification — 2026-09-07
- TypeScript check and both Wrangler dry runs passed.
- Local redirects passed for privacy, terms, support, root, query preservation,
  and a double-slash path (destination host stays skygrid.my).
- Deployed site version: 07ac63fb-98a0-4e74-ace5-796c76dae722.
- Deployed legal version: d7500a7a-2abf-4d3f-b8be-92e56ebdd961.
- Browser runtime returned no available browsers; full-page rendering and
  interactive light/dark visual checks remain unverified. OG image inspected.
- Python urllib received 403 while curl received 200; verification uses curl.
- Public root, support, terms, privacy: HTTP 200, exact expected titles and
  byte-for-byte local HTML equality. Referenced assets match local hashes.
- Legacy /privacy: HTTP 301 to https://skygrid.my/privacy; followed response
  HTTP 200 with the correct privacy title.

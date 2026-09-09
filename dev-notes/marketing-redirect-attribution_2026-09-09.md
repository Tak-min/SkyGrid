# Marketing redirect attribution — 2026-09-09

Added coarse, privacy-preserving attribution for TikTok/Instagram bio links.

- `GET /get/{placement}` accepts 1–64 ASCII letters, digits, or hyphens, records only
  `placement` and a D1-generated UTC `created_at`, then redirects with HTTP 302 to
  `https://apps.apple.com/app/id6796222704`.
- `HEAD /get/{placement}` returns the same redirect without recording an event, so
  health checks and `curl -I` do not inflate counts.
- `GET /api/get-stats?since=YYYY-MM-DD` returns counts grouped by placement and requires
  `Authorization: Bearer <STATS_TOKEN>`.
- D1 table: `app_store_redirects`. Apply `schema.sql` with `npm run db:migrate` before
  deploying the Worker.
- Configure the read token separately with `npx wrangler secret put STATS_TOKEN`.

The count denominator is redirect GETs, not unique visitors, App Store views, or
downloads. No IP address, User-Agent, Cookie, or other request metadata is persisted.

import { APPLE_APP_SITE_ASSOCIATION } from "./aasa";
import { parseInviteCode, renderInvitePage } from "./invitePage";

export interface Env {
  ASSETS: Fetcher;
  DB: D1Database;
  STATS_TOKEN: string;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_EMAIL_LENGTH = 254;
const PLACEMENT_RE = /^[A-Za-z0-9-]{1,64}$/;
const APP_STORE_URL = "https://apps.apple.com/app/id6796222704";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" }
  });
}

async function handleWaitlistSignup(request: Request, env: Env): Promise<Response> {
  let payload: { email?: unknown; company?: unknown };
  try {
    payload = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  // Honeypot: a hidden form field real users never fill in.
  if (typeof payload.company === "string" && payload.company.trim() !== "") {
    return json({ ok: true });
  }

  const email = typeof payload.email === "string" ? payload.email.trim().toLowerCase() : "";
  if (!email || email.length > MAX_EMAIL_LENGTH || !EMAIL_RE.test(email)) {
    return json({ error: "invalid_email" }, 400);
  }

  await env.DB.prepare(
    "INSERT INTO waitlist_signups (email) VALUES (?1) ON CONFLICT(email) DO NOTHING"
  )
    .bind(email)
    .run();

  return json({ ok: true });
}

function appStoreRedirect(): Response {
  return new Response(null, {
    status: 302,
    headers: {
      location: APP_STORE_URL,
      "cache-control": "no-store"
    }
  });
}

async function handleAppStoreRedirect(
  request: Request,
  env: Env,
  pathname: string
): Promise<Response> {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const placement = pathname.startsWith("/get/") ? pathname.slice("/get/".length) : "";
  if (!PLACEMENT_RE.test(placement)) {
    return json({ error: "invalid_placement" }, 400);
  }

  // HEAD supports link checks without adding synthetic traffic to the measurement.
  if (request.method === "HEAD") {
    return appStoreRedirect();
  }

  await env.DB.prepare(
    "INSERT INTO app_store_redirects (placement) VALUES (?1)"
  )
    .bind(placement)
    .run();

  return appStoreRedirect();
}

function isValidDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }

  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.valueOf()) && date.toISOString().slice(0, 10) === value;
}

async function handleGetStats(request: Request, env: Env, url: URL): Promise<Response> {
  if (request.method !== "GET") {
    return json({ error: "method_not_allowed" }, 405);
  }

  if (!env.STATS_TOKEN) {
    return json({ error: "stats_not_configured" }, 503);
  }
  if (request.headers.get("authorization") !== `Bearer ${env.STATS_TOKEN}`) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": "no-store",
        "www-authenticate": "Bearer"
      }
    });
  }

  const since = url.searchParams.get("since") ?? "";
  if (!isValidDate(since)) {
    return json({ error: "invalid_since" }, 400);
  }

  const { results } = await env.DB.prepare(
    `SELECT placement, COUNT(*) AS count
     FROM app_store_redirects
     WHERE created_at >= ?1
     GROUP BY placement
     ORDER BY placement`
  )
    .bind(`${since} 00:00:00`)
    .all<{ placement: string; count: number }>();

  return new Response(JSON.stringify({ since, placements: results }), {
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store"
    }
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (
      url.pathname === "/.well-known/apple-app-site-association" ||
      url.pathname === "/apple-app-site-association"
    ) {
      return new Response(JSON.stringify(APPLE_APP_SITE_ASSOCIATION), {
        headers: { "content-type": "application/json" }
      });
    }

    if (url.pathname === "/i" || url.pathname.startsWith("/i/")) {
      return new Response(renderInvitePage(
        parseInviteCode(url.pathname),
        url.hostname.toLowerCase() === "open.skygrid.my"
      ), {
        headers: { "content-type": "text/html; charset=utf-8" }
      });
    }

    if (url.pathname === "/api/waitlist") {
      if (request.method !== "POST") {
        return json({ error: "method_not_allowed" }, 405);
      }
      return handleWaitlistSignup(request, env);
    }

    if (url.pathname === "/get" || url.pathname.startsWith("/get/")) {
      return handleAppStoreRedirect(request, env, url.pathname);
    }

    if (url.pathname === "/api/get-stats") {
      return handleGetStats(request, env, url);
    }

    return env.ASSETS.fetch(request);
  }
} satisfies ExportedHandler<Env>;

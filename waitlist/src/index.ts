import { APPLE_APP_SITE_ASSOCIATION } from "./aasa";
import { parseInviteCode, renderInvitePage } from "./invitePage";

export interface Env {
  ASSETS: Fetcher;
  DB: D1Database;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_EMAIL_LENGTH = 254;

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

    return env.ASSETS.fetch(request);
  }
} satisfies ExportedHandler<Env>;

/**
 * Fallback landing page for `/i/{code}` when Universal Links don't intercept the
 * tap (app not installed, or Apple hasn't re-fetched AASA yet after this domain's
 * Associated Domains entitlement was added). Served inline from the Worker rather
 * than through `env.ASSETS` — Workers Assets 307-redirects any `.html` URL to its
 * extensionless form (confirmed against `/privacy.html` in production), which
 * would turn a plain `env.ASSETS.fetch("/invite.html")` into a redirect object
 * instead of page content.
 *
 * Crockford Base32 minus I/L/O/U (see `ios/functions/src/invites.ts`,
 * `INVITE_ALPHABET`) has no HTML-special characters, so a code that matches this
 * pattern is safe to interpolate as-is. A code that doesn't match is never
 * reflected into the response at all — the page just falls back to a codeless
 * App Store link instead of trusting attacker-controlled path input.
 */
const INVITE_CODE_PATTERN = /^[0-9A-HJKMNP-TV-Z]{10}$/;
const APP_STORE_URL = "https://apps.apple.com/us/app/sky-grid-morning-wake/id6796222704";
const APP_STORE_ID = "6796222704";

export function parseInviteCode(pathname: string): string | null {
  const match = /^\/i\/([^/]+)\/?$/.exec(pathname);
  if (!match) return null;
  const candidate = match[1].toUpperCase();
  return INVITE_CODE_PATTERN.test(candidate) ? candidate : null;
}

export function renderInvitePage(code: string | null, isRecoveryHost = false): string {
  const canonicalUrl = code ? `https://skygrid.my/i/${code}` : "https://skygrid.my/i/";
  const appUrl = code ? `https://open.skygrid.my/i/${code}` : null;
  const primaryAction = appUrl && !isRecoveryHost
    ? `<a class="download-cta" href="${appUrl}">Open Sky Grid</a>\n      <a class="store-link" href="${APP_STORE_URL}" target="_blank" rel="noopener">Download on the App Store</a>`
    : `<a class="download-cta" href="${APP_STORE_URL}" target="_blank" rel="noopener">Download on the App Store</a>`;
  const recoveryNote = isRecoveryHost
    ? "Install Sky Grid, sign in, then return to the original invite link to connect."
    : "Already installed but still seeing this page? Tap Open Sky Grid above, or tap OPEN in Safari's app banner to restore direct opening.";

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sky Grid — You've been invited</title>
<meta name="description" content="A friend invited you to Sky Grid. Open this link on their phone to connect, or download the app to get started.">
<meta property="og:title" content="Sky Grid — You've been invited">
<meta property="og:description" content="One photo of the sky each morning, together with a friend.">
<meta property="og:image" content="/images/00-skygrid-overview-v1.webp">
<meta property="og:type" content="website">
<meta name="twitter:card" content="summary_large_image">
<meta name="apple-itunes-app" content="app-id=${APP_STORE_ID}, app-argument=${canonicalUrl}">
<link rel="icon" href="/images/favicon.png">
<link rel="apple-touch-icon" href="/images/apple-touch-icon.png">
<link rel="stylesheet" href="/style.css">
</head>
<body>

<header>
  <div class="brand">
    <img src="/images/app-icon.webp" alt="" width="28" height="28">
    <span>Sky Grid</span>
  </div>
  <span class="badge"><i class="dot"></i>Live on the App Store</span>
</header>

<main>
  <section class="hero">
    <div class="hero-copy">
      <h1>You've been invited to Sky Grid.</h1>
      <p class="lede">A friend wants to share their mornings with you. Open Sky Grid to review the invitation, or download it first and return to this link.</p>
      <div class="invite-actions">${primaryAction}</div>
      <p class="form-note">${recoveryNote}</p>
    </div>
  </section>
</main>

<footer>
  <div class="footer-brand">
    <div class="brand">
      <img src="/images/app-icon.webp" alt="" width="24" height="24">
      <span>Sky Grid</span>
    </div>
    <p>One photo of the sky each morning. A year, one grid.</p>
  </div>
  <div class="footer-links">
    <div class="footer-col">
      <h3>Legal</h3>
      <a href="/privacy">Privacy</a>
      <a href="/terms">Terms of Use</a>
    </div>
    <div class="footer-col">
      <h3>Contact</h3>
      <a href="mailto:taku810616@gmail.com">Email us</a>
    </div>
  </div>
  <p class="copyright">© Sky Grid</p>
</footer>

</body>
</html>
`;
}

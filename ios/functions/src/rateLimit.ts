/**
 * Fixed-window per-caller rate limiting, as a pure decision.
 *
 * Kept free of `firebase-admin` for the same reason as `subscriptionState.ts` and
 * `invites.ts`: the off-by-one at the window edge is exactly the kind of thing that is
 * trivial to get wrong and impossible to see in an emulator run.
 *
 * **What this is actually for.** An invite code is 50 bits, and at any moment there are
 * on the order of 10²–10⁴ live ones, so an enumerator needs ~10¹¹ guesses to expect a
 * single hit. That is out of reach with or without a limiter. The limiter exists to
 * bound *cost and availability* — Firestore reads and Cloud Functions invocations
 * billed to this project — not to protect the code space, which entropy already
 * protects. Sizing the limits accordingly is why they are generous.
 *
 * **Every code-taking callable is limited, not just `previewInvite`.** `claimInvite`
 * answers the same existence question, so limiting preview alone would be bypassed by
 * one line of attacker code. `revokeInvite` is exempt only because its response is
 * identical for "no such code" and "not your code" (see `revokeInviteDocument`), which
 * leaves it with nothing to enumerate.
 */

export type RateLimitedAction = "preview" | "claim" | "create" | "buddyRequest" | "buddyAccept";

export interface RateLimitWindow {
  windowStartMs: number;
  count: number;
}

export interface RateLimitDecision {
  allowed: boolean;
  /**
   * The window to persist, or `null` when the call was rejected. A rejected call
   * writes nothing: that is what keeps a flood of over-limit requests cheap, and it
   * also means an attacker cannot extend their own lockout by continuing to hammer.
   */
  nextWindow: RateLimitWindow | null;
}

export const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;

/**
 * Deliberately generous. These are the number of *different people* a single account
 * could plausibly be exchanging invites with in an hour, times a wide margin for
 * retries and mistypes, because a legitimate user hitting this limit is a far worse
 * outcome than an attacker paying for a few thousand reads.
 */
export const RATE_LIMITS: Readonly<Record<RateLimitedAction, number>> = {
  preview: 20,
  claim: 10,
  create: 10,
  buddyRequest: 20,
  buddyAccept: 20,
};

/**
 * The window is anchored to the caller's first request in it, not to wall-clock hours,
 * so a caller cannot get two full budgets by straddling the top of an hour. They can
 * still burst up to ~2x the limit across one boundary — the standard fixed-window
 * tradeoff, accepted here because the limiter is a cost bound rather than a security
 * boundary.
 *
 * Never mutates `current`.
 */
export function rateLimitDecision(
  current: RateLimitWindow | null,
  nowMs: number,
  windowMs: number,
  limit: number
): RateLimitDecision {
  const isWindowLive = current !== null && nowMs - current.windowStartMs < windowMs;

  if (!isWindowLive) {
    return { allowed: true, nextWindow: { windowStartMs: nowMs, count: 1 } };
  }
  if (current.count >= limit) {
    return { allowed: false, nextWindow: null };
  }
  return {
    allowed: true,
    nextWindow: { windowStartMs: current.windowStartMs, count: current.count + 1 },
  };
}

/**
 * The server-side mirror of the only commercial plan states exposed by the iOS
 * app. This document is informational; RevenueCat remains the entitlement
 * authority in the client. Circle-cap decisions that need Pro status query
 * RevenueCat's Customer API live rather than trusting this asynchronous mirror,
 * so neither a delayed purchase nor a delayed expiration/refund can decide access.
 */
export type SubscriptionPlan = "free" | "monthly" | "annual" | "lifetime";

export interface SubscriptionSnapshot {
  plan: SubscriptionPlan;
  isPro: boolean;
  willRenew: boolean;
}

export interface RevenueCatSubscriptionEvent {
  type: string;
  product_id?: string | null;
}

export const FREE_SUBSCRIPTION: SubscriptionSnapshot = {
  plan: "free",
  isPro: false,
  willRenew: false,
};

export function planForProductID(productID: string | null | undefined): SubscriptionPlan | null {
  switch (productID) {
    case "com.takmin.skygrid.pro.monthly":
    case "com.takmin.skygrid.pro.monthly.secondchance":
      return "monthly";
    case "com.takmin.skygrid.pro.annual":
      return "annual";
    case "com.takmin.skygrid.pro.lifetime":
      return "lifetime";
    default:
      return null;
  }
}

/**
 * Applies lifecycle events that affect whether a recognised Sky Grid product is
 * usable. Cancellations retain access through the already-paid period; only an
 * expiration removes it. The function is pure so it can be tested independently
 * from Firebase delivery and retry mechanics.
 */
export function nextSubscriptionSnapshot(
  current: SubscriptionSnapshot,
  event: RevenueCatSubscriptionEvent,
): SubscriptionSnapshot {
  const plan = planForProductID(event.product_id);

  switch (event.type) {
    case "EXPIRATION":
      return FREE_SUBSCRIPTION;
    case "CANCELLATION":
      // A cancellation webhook can be the first delivery we see (for example
      // after a webhook endpoint is added). It still represents a paid period
      // that remains usable until its later EXPIRATION event.
      guardRecognisedPlan(plan);
      return { plan, isPro: true, willRenew: false };
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "UNCANCELLATION":
    case "NON_RENEWING_PURCHASE":
    case "PRODUCT_CHANGE":
    case "SUBSCRIPTION_EXTENDED":
    case "REFUND_REVERSED":
      guardRecognisedPlan(plan);
      return {
        plan,
        isPro: true,
        willRenew: plan !== "lifetime",
      };
    default:
      return current;
  }
}

function guardRecognisedPlan(plan: SubscriptionPlan | null): asserts plan is Exclude<SubscriptionPlan, "free"> {
  if (!plan || plan === "free") {
    throw new Error("Sky Grid webhook used an unrecognised paid product.");
  }
}

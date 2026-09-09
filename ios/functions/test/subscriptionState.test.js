const test = require("node:test");
const assert = require("node:assert/strict");

const {
  FREE_SUBSCRIPTION,
  nextSubscriptionSnapshot,
  planForProductID,
} = require("../lib/subscriptionState.js");

test("maps the normal catalog and second-chance monthly product", () => {
  assert.equal(planForProductID("com.takmin.skygrid.pro.monthly"), "monthly");
  assert.equal(planForProductID("com.takmin.skygrid.pro.monthly.secondchance"), "monthly");
  assert.equal(planForProductID("com.takmin.skygrid.pro.annual"), "annual");
  assert.equal(planForProductID("com.takmin.skygrid.pro.lifetime"), "lifetime");
  assert.equal(planForProductID("com.takmin.skygrid.pro.weekly"), null);
});

test("keeps access after cancellation and removes it only at expiration", () => {
  const annual = nextSubscriptionSnapshot(FREE_SUBSCRIPTION, {
    type: "INITIAL_PURCHASE",
    product_id: "com.takmin.skygrid.pro.annual",
  });
  assert.deepEqual(annual, { plan: "annual", isPro: true, willRenew: true });

  const cancelled = nextSubscriptionSnapshot(annual, {
    type: "CANCELLATION",
    product_id: "com.takmin.skygrid.pro.annual",
  });
  assert.deepEqual(cancelled, { plan: "annual", isPro: true, willRenew: false });

  assert.deepEqual(
    nextSubscriptionSnapshot(cancelled, { type: "EXPIRATION" }),
    FREE_SUBSCRIPTION,
  );
});

test("a cancellation can establish still-active access when earlier events were missed", () => {
  const cancelled = nextSubscriptionSnapshot(FREE_SUBSCRIPTION, {
    type: "CANCELLATION",
    product_id: "com.takmin.skygrid.pro.monthly",
  });

  assert.deepEqual(cancelled, {
    plan: "monthly",
    isPro: true,
    willRenew: false,
  });
});
